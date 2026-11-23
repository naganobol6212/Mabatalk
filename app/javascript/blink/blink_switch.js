// まばたき判定の状態機械。DOM もタイマーも時計も持たず、
// 「今の状態 + 入力（時刻つき）+ 設定」から「次の状態 + イベント」を返すだけ。
//
// phase（state.phase で読める）:
//   noface 顔なし / arming 準備中 / open 開眼 / closing 閉眼中 /
//   ready 決定待ち / refractory 安定待ち / rest 休憩
//
// 入力:
//   { type: "frame", now, currentGeneration, frame }  推論結果が1つ届いた
//   { type: "tick", now, currentGeneration }          結果が来ているかの見張り
//       結果が届かない間も定期的に呼ぶ。scan_sequencer の tick より先に呼び、戻りの phase を渡す
//       （呼び出し順は scan_sequencer.js の先頭）
//   frame = { capturedAt, seq, generation, highlightedKey, faceDetected,
//             leftScore, rightScore, face: { x, y, size } }
//   leftScore / rightScore は本人から見た左右の「閉じ具合」（0〜1）。
//
// イベント:
//   { type: "holdReached", key }   保持時間に届いた（合図の音を鳴らす所）
//   { type: "select", key }        決定
//   { type: "rest", key }          閉じたままが長いので休憩とみなした（決定しない）
//   { type: "cancel", reason, key } 候補を捨てた
//       reason: shortBlink / faceLost / faceChanged / frameGap / watchdog / generationChanged
//   { type: "discard", reason }    届いた入力を使わなかった（状態は変わらない）
//       reason: generation / stale / outOfOrder /
//               invalidTime（now や capturedAt が有限の数値でない・capturedAt が now より先）/
//               invalidSeq（seq が整数でない）
//
// 世代の決まり: currentGeneration が前の入力から変わったら（画面が切り替わったら）、
// 保持の途中の候補は取り消し、新しい世代のフレームで開眼を 1 度見るまで閉じ始めを受け付けない。
// 前の画面に向けて閉じた目が、新しい画面の項目の決定になるのを防ぐ。
//
// 時計の決まり: now と capturedAt は同じ単調な時計（performance.now()）の値で、capturedAt ≦ now。
// 別の基準の時計（Worker 側の performance.now() など）で capturedAt を作り直さないこと。
// 守られていない入力は、判定に使わず入口で捨てる（上の invalidTime / invalidSeq）。
//
// 用語: ここの「休憩（rest）」は、目を長く閉じたままなので決定しないという判定の状態。
// scan_sequencer の「休止（paused）」は、スキャンを止めている画面の状態で、別のもの。
//
// 限界: 顔が1つ映っていることは、それが本人であることを意味しない。
// 顔の位置・大きさの急変で取り消すのは、その取り違えを減らすための手当てにすぎない。

import { FIXED } from "./config.js"

const isNumber = (value) => typeof value === "number" && Number.isFinite(value)

export function createBlinkSwitch() {
  return {
    phase: "noface",
    candidateKey: null,
    generation: null,
    awaitingOpen: false,
    since: null,
    unusableSince: null,
    lastSeq: null,
    lastCapturedAt: null,
    lastReceivedAt: null,
    lastFace: null
  }
}

// 使う目に合わせた1フレームのスコア。数値として使えなければ null（0 = 開眼とはみなさない）。
export function eyeScore(frame, eye) {
  if (!frame) return null
  const { leftScore, rightScore } = frame
  if (eye === "left") return isNumber(leftScore) ? leftScore : null
  if (eye === "right") return isNumber(rightScore) ? rightScore : null
  return isNumber(leftScore) && isNumber(rightScore) ? (leftScore + rightScore) / 2 : null
}

export function stepBlinkSwitch(state, input, settings) {
  const invalid = invalidInputReason(input)
  if (invalid) return { state, events: [{ type: "discard", reason: invalid }] }

  const events = []
  let next = syncGeneration(state, input.currentGeneration, events)
  if (input.type === "tick") next = watch(next, input.now, events)
  if (input.type === "frame") {
    const reason = discardReason(next, input)
    if (reason) return { state: next, events: [...events, { type: "discard", reason }] }
    next = acceptFrame(next, input, settings, events)
  }
  return { state: next, events }
}

// 時計や通し番号がおかしい入力は、状態に触れる前に捨てる。
// NaN は大小の比べ方がすべて false になるので、通すと「古くない」「途切れていない」と誤って扱われる。
function invalidInputReason({ type, now, frame }) {
  if (!isNumber(now)) return "invalidTime"
  if (type !== "frame") return null
  if (!isNumber(frame?.capturedAt) || frame.capturedAt > now) return "invalidTime"
  if (!Number.isInteger(frame.seq)) return "invalidSeq"
  return null
}

function toArming(state, reason, events) {
  if (state.phase === "closing" || state.phase === "ready") {
    events.push({ type: "cancel", reason, key: state.candidateKey })
  }
  return { ...state, phase: "arming", candidateKey: null, since: null, unusableSince: null }
}

function toNoFace(state, events) {
  if (state.phase === "closing" || state.phase === "ready") {
    events.push({ type: "cancel", reason: "faceLost", key: state.candidateKey })
  }
  return { ...state, phase: "noface", candidateKey: null, since: null, unusableSince: null, lastFace: null }
}

// 画面の世代が変わったら、前の画面で固定した候補は持ち越さない。
// 前の画面から閉じたままの目も持ち越さない: 新しい世代で開眼を 1 度見るまで（awaitingOpen）、
// 閉じた目を閉じ始めとして受け付けない。phase は変えないので、開眼ならスキャンの時計は進む。
//
// 限界（PR3b でカメラをつなぐ前に直す）: awaitingOpen のあいだも phase は "open" のままなので、
// 前の画面から目を閉じ続けている（まだ開眼を確かめられていない）時も、スキャンの時計は進んでしまう。
// 「開眼を確かめられていない時は時計を止める」には、準備中（arming）へ戻すか、受け付けられないことを
// 別の形で呼び出し側へ伝える必要がある。PR2 の入力はキー（key_switch）で、この判定は画面につないでいない。
function syncGeneration(state, currentGeneration, events) {
  if (state.generation === currentGeneration) return state
  const synced = { ...state, generation: currentGeneration, awaitingOpen: state.generation !== null }
  const holding = state.phase === "closing" || state.phase === "ready"
  return holding && state.generation !== null ? toArming(synced, "generationChanged", events) : synced
}

function watch(state, now, events) {
  if (state.phase === "noface" || state.lastReceivedAt === null) return state
  if (now - state.lastReceivedAt < FIXED.watchdogMs) return state
  return toArming(state, "watchdog", events)
}

function discardReason(state, { now, currentGeneration, frame }) {
  if (frame.generation !== currentGeneration) return "generation"
  if (now - frame.capturedAt >= FIXED.maxResultAgeMs) return "stale"
  if (state.lastSeq !== null && frame.seq <= state.lastSeq) return "outOfOrder"
  if (state.lastCapturedAt !== null && frame.capturedAt < state.lastCapturedAt) return "outOfOrder"
  return null
}

function acceptFrame(state, { now, frame }, settings, events) {
  const t = frame.capturedAt
  const eye = classify(frame, settings)
  let next = state

  if (state.lastCapturedAt !== null && t - state.lastCapturedAt > FIXED.maxFrameGapMs) {
    if (next.phase === "closing" || next.phase === "ready" || next.phase === "arming") {
      next = toArming(next, "frameGap", events)
    }
  }
  if (eye !== "unusable" && next.lastFace && faceJumped(next.lastFace, frame.face)) {
    next = toArming(next, "faceChanged", events)
  }

  next = { ...next, lastSeq: frame.seq, lastCapturedAt: t, lastReceivedAt: now }
  if (eye === "unusable") return onUnusable(next, t, settings, events)
  // 顔が戻ったフレームでも猶予の期限を確かめる。使えないフレームが来た時だけ確かめると、
  // 猶予を過ぎてから戻った顔が、開眼の確認（準備中）を通らずにそのまま続いてしまう。
  if (graceExpired(next, t, settings)) next = toNoFace(next, events)
  next = { ...next, lastFace: frame.face, unusableSince: null, awaitingOpen: next.awaitingOpen && eye !== "open" }
  return onEye[next.phase](next, eye, t, frame, settings, events)
}

// "open" / "between"（しきい値のあいだ）/ "closed" / "unusable"（顔が無い・スコアや顔の枠が欠けている）
function classify(frame, settings) {
  const score = eyeScore(frame, settings.eye)
  const face = frame.face
  const faceOk = frame.faceDetected === true && face && isNumber(face.x) && isNumber(face.y) && isNumber(face.size) && face.size > 0
  if (!faceOk || score === null) return "unusable"
  if (score >= settings.closeThreshold) return "closed"
  if (score <= settings.openThreshold) return "open"
  return "between"
}

function faceJumped(previous, current) {
  const shift = Math.hypot(current.x - previous.x, current.y - previous.y)
  const sizeRatio = Math.max(current.size, previous.size) / Math.min(current.size, previous.size)
  return shift > previous.size * FIXED.faceShiftRatio || sizeRatio > FIXED.faceSizeRatio
}

// 保持の途中（closing / ready）は、使えないフレームが1つでも入ったら取り消す。
// 開眼・安定待ちは、表示がちらつかないよう猶予（faceLostGraceMs）を超えるまで待つ。
function onUnusable(state, t, settings, events) {
  if (state.phase === "noface") return state
  if (state.phase !== "open" && state.phase !== "refractory") return toNoFace(state, events)
  const waiting = { ...state, unusableSince: state.unusableSince ?? t }
  return graceExpired(waiting, t, settings) ? toNoFace(waiting, events) : waiting
}

// 最初に使えなくなったフレームから数えて、猶予を超えたか（ちょうどは超えていない）。
function graceExpired(state, t, settings) {
  return state.unusableSince !== null && t - state.unusableSince > settings.faceLostGraceMs
}

// 状態ごとの「目の様子を見たらどうするか」。しきい値のあいだ（between）は、
// 開いた証拠にも閉じた証拠にもしない（= 開眼では閉じ始めず、閉眼中は閉じたままとして数える）。
const onEye = {
  noface(state, eye, t) {
    return { ...state, phase: "arming", since: eye === "open" ? t : null }
  },

  arming(state, eye, t, _frame, settings) {
    if (eye !== "open") return { ...state, since: null }
    const since = state.since ?? t
    if (t - since >= settings.armingMs) return { ...state, phase: "open", since: null }
    return { ...state, since }
  },

  open(state, eye, t, frame) {
    if (eye !== "closed" || state.awaitingOpen) return state
    return { ...state, phase: "closing", candidateKey: frame.highlightedKey ?? null, since: t }
  },

  // 「保持時間の前に開いた」時だけ捨てる。保持時間に届いたフレームが開眼だった時は、
  // 決定待ちに入ったうえで、同じフレームを決定待ちとして見る（holdReached と select を1回ずつ）。
  closing(state, eye, t, frame, settings, events) {
    if (t - state.since >= settings.holdMs) {
      events.push({ type: "holdReached", key: state.candidateKey })
      return onEye.ready({ ...state, phase: "ready" }, eye, t, frame, settings, events)
    }
    if (eye !== "open") return state
    events.push({ type: "cancel", reason: "shortBlink", key: state.candidateKey })
    return { ...state, phase: "open", candidateKey: null, since: null }
  },

  ready(state, eye, t, _frame, settings, events) {
    if (t - state.since >= settings.restMs) {
      events.push({ type: "rest", key: state.candidateKey })
      return { ...state, phase: "rest", candidateKey: null, since: null }
    }
    if (eye !== "open") return state
    events.push({ type: "select", key: state.candidateKey })
    return { ...state, phase: "refractory", candidateKey: null, since: t }
  },

  refractory(state, eye, t, _frame, settings) {
    if (eye === "open" && t - state.since >= settings.refractoryMs) return { ...state, phase: "open", since: null }
    return state
  },

  rest(state, eye, t) {
    if (eye !== "open") return state
    return { ...state, phase: "arming", since: t }
  }
}
