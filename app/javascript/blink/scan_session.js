// スキャン画面の状態（scan_controller が持つ）。DOM もタイマーも通信も時計も持たず、
// 「今の状態 + 入力」から「次の状態 + してほしいこと（effects）」を返すだけ。
//
// phase（scanView(state).screen で読める）:
//   idle 開始前・介助者が止めた（届いたか分からない送信があれば pending に残したまま止まる）/ running スキャン中（中身は scan_sequencer: scanning・confirming・paused）/
//   suspended 画面が隠れている（戻ったら先頭から再開する）/ sending 送信中 / done 完了表示 /
//   unknown 届いたか確認できない / halted 介助者を呼ぶ（読み込み直すまで動かない）
//
// 入力:
//   { type: "start" } / { type: "stop" }        介助者の「開始」「停止」
//   { type: "suspend" } / { type: "resume" }    画面が隠れた / 戻った
//   { type: "switch", now, phase, events }      入力源の結果（key_switch。PR3b からは blink_switch も）。
//                                               events の select を決定として使い、phase で時計を進める
//   { type: "sendResult", now, attempt, outcome }  送信の返事（outcome は sendOutcome の戻り）
//   { type: "retry" }                           介助者の「もう一度送る」
//
// effects:
//   { type: "send", attempt, flowItemKey, submissionId }  記録を送る。返事は同じ attempt を付けて sendResult で返す
//   { type: "cancelSend" }   送信中の通信を打ち切る
//   { type: "resetInput" }   入力源を最初の状態に戻す（前の押下・閉眼を持ち越さない）
//
// 送信ID は「はい」を決めた時に 1 回だけ作り、送り直しでも同じ値を使う。
// 「止める」（入力を受けない）と「届いたか」（pending）は別に持つ: 記録できた・介助者を呼ぶ、のどちらかの
// 返事が来るまで pending は消さない。送信中・「確認できません」で停止しても残し、次の「開始」は
// スキャンではなく「確認できません」に戻す（消すと、次の「はい」が新しい送信ID になり二重に記録される）。
// attempt は送信のたびに進む通し番号。止めたあと・送り直したあとに届いた古い返事を見分けて捨てる。

import { DEFAULTS } from "./config.js"
import { highlightedKey, startScan, stepScan } from "./scan_sequencer.js"

const isPositive = (value) => typeof value === "number" && Number.isFinite(value) && value > 0
const isCount = (value) => Number.isInteger(value) && value > 0

// キー入力で使う設定の名前と、上書きを受け付ける条件。
// まばたきのしきい値・使う目・保持時間はここに無い（キー入力では使わない。PR3b で調整結果から作る）。
// 上書きは system spec が時間を短くするためのもので、調整範囲（RANGES）では確かめない。
const TIMING = {
  stepMs: isPositive,
  // 先頭の項目の時間は、1 項目の時間より短くしない（PR1 の決まり）
  firstStepRatio: (value) => isPositive(value) && value >= 1,
  autoPauseRounds: isCount,
  confirmRounds: isCount,
  refractoryMs: isPositive,
  doneMs: isPositive
}

export function timingSettings(overrides) {
  const given = overrides && typeof overrides === "object" ? overrides : {}
  return Object.fromEntries(
    Object.entries(TIMING).map(([name, accepts]) => [name, accepts(given[name]) ? given[name] : DEFAULTS[name]])
  )
}

const HALT_REASONS = { 401: "unauthorized", 403: "forbidden", 404: "notFound", 409: "conflict", 422: "reload", 429: "rateLimited" }

// 送信の返事（状態コードと JSON の中身）を、画面の動きに読み替える。
// 通信エラー・時間切れで返事が無い時は null / undefined を渡す。
export function sendOutcome(response) {
  const reason = HALT_REASONS[response?.status]
  if (reason) return { kind: "halt", reason }
  const saved = response?.status === 200 || response?.status === 201
  const name = response?.body?.name
  if (!saved || typeof name !== "string" || name === "") return { kind: "unknown" }
  return { kind: "saved", name, savedToHistory: response.body.saved_to_history === true }
}

// items: [{ key, kind? }]（scan_sequencer と同じ）。newSubmissionId: 送信ID を作る関数（crypto.randomUUID）
export function createScanSession({ items, settings, newSubmissionId }) {
  const started = startScan(items, settings)
  if (!started.ok) return started
  return {
    ok: true,
    state: {
      items,
      settings,
      newSubmissionId,
      phase: "idle",
      scan: null,
      pending: null,
      attempt: 0,
      failures: 0,
      done: null,
      doneUntil: null,
      haltReason: null
    }
  }
}

// 画面に出すもの
export function scanView(state) {
  const running = state.phase === "running"
  return {
    screen: running ? state.scan.mode : state.phase === "suspended" ? "idle" : state.phase,
    highlightedKey: running ? highlightedKey(state.scan) : null,
    pendingKey: running ? state.scan.pendingKey : state.pending?.flowItemKey ?? null,
    done: state.done,
    haltReason: state.haltReason,
    failures: state.failures
  }
}

export function stepScanSession(state, input) {
  const handler = handlers[input.type]?.[state.phase]
  return handler ? handler(state, input) : { state, effects: [] }
}

const RESET_INPUT = { type: "resetInput" }
const CANCEL_SEND = { type: "cancelSend" }

// スキャンを先頭からやり直す（前の候補・確認の途中・入力源の状態を持ち越さない）
function restart(state) {
  const scan = startScan(state.items, state.settings).state
  return {
    state: { ...state, phase: "running", scan, pending: null, done: null, doneUntil: null },
    effects: [RESET_INPUT]
  }
}

function toIdle(state) {
  return {
    state: { ...state, phase: "idle", scan: null, pending: null, done: null, doneUntil: null, failures: 0, attempt: state.attempt + 1 },
    effects: [CANCEL_SEND, RESET_INPUT]
  }
}

// 届いたか分からない送信を残したまま止める。failures: これまでに「届いたか分からない」で終わった回数
function toIdleKeepingPending(state, failures) {
  return {
    state: { ...state, phase: "idle", scan: null, failures, attempt: state.attempt + 1 },
    effects: [CANCEL_SEND, RESET_INPUT]
  }
}

function send(state, pending) {
  const attempt = state.attempt + 1
  return {
    state: { ...state, phase: "sending", scan: null, pending, attempt },
    effects: [{ type: "send", attempt, ...pending }]
  }
}

function onSwitchWhileRunning(state, { now, phase, events }) {
  let scan = state.scan
  const outputs = []
  const apply = (input) => {
    const stepped = stepScan(scan, input, state.settings)
    scan = stepped.state
    outputs.push(...stepped.events)
  }
  // 順番は scan_sequencer.js の先頭の決まりどおり: 決定を渡してから、最後に時計
  for (const event of events) if (event.type === "select") apply({ type: "select", now, key: event.key })
  apply({ type: "tick", now, eyePhase: phase })

  const confirmed = outputs.find((output) => output.type === "confirmed")
  if (!confirmed) return { state: { ...state, scan }, effects: [] }
  return send(state, { flowItemKey: confirmed.key, submissionId: state.newSubmissionId() })
}

function onSendResult(state, { now, attempt, outcome }) {
  if (attempt !== state.attempt) return { state, effects: [] }
  if (outcome.kind === "saved") {
    const done = { name: outcome.name, savedToHistory: outcome.savedToHistory }
    return { state: { ...state, phase: "done", pending: null, failures: 0, done, doneUntil: now + state.settings.doneMs }, effects: [] }
  }
  if (outcome.kind === "halt") {
    return { state: { ...state, phase: "halted", pending: null, haltReason: outcome.reason }, effects: [] }
  }
  return { state: { ...state, phase: "unknown", failures: state.failures + 1 }, effects: [] }
}

// 入力ごとの「どの phase の時に、どうするか」。ここに無い組み合わせは何もしない。
const handlers = {
  start: { idle: (state) => (state.pending ? { state: { ...state, phase: "unknown" }, effects: [] } : restart(state)) },

  stop: {
    running: toIdle,
    suspended: toIdle,
    done: toIdle,
    // 返事を待たずに打ち切る（サーバーが保存を終えているかもしれない）
    sending: (state) => toIdleKeepingPending(state, state.failures + 1),
    unknown: (state) => toIdleKeepingPending(state, state.failures)
  },

  suspend: {
    running: (state) => ({ state: { ...state, phase: "suspended", scan: null }, effects: [RESET_INPUT] }),
    done: (state) => ({ state: { ...state, phase: "suspended", done: null, doneUntil: null }, effects: [RESET_INPUT] }),
    // 返事を待たずに打ち切る。届いたかは分からないので、戻った時に「確認できません」で介助者に任せる
    sending: (state) => ({
      state: { ...state, phase: "unknown", failures: state.failures + 1, attempt: state.attempt + 1 },
      effects: [CANCEL_SEND]
    })
  },

  resume: { suspended: restart },

  switch: {
    running: onSwitchWhileRunning,
    done: (state, { now }) => (now >= state.doneUntil ? restart(state) : { state, effects: [] })
  },

  sendResult: { sending: onSendResult },

  retry: { unknown: (state) => send(state, state.pending) }
}
