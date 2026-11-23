// 今どの項目を光らせるかを決める。DOM もタイマーも時計も持たず、
// 「今の状態 + 入力（時刻つき）+ 設定」から「次の状態 + イベント」を返すだけ。
//
// mode（state.mode で読める）:
//   scanning 項目を順に光らせている / confirming 「いいえ/はい」で確認中 /
//   paused 休止中 / finished 「はい」で確定して止まった
//
// 入力:
//   { type: "tick", now, eyePhase }  時計を進める。eyePhase は blink_switch の phase
//   { type: "select", now, key }     blink_switch が出した決定
//
// イベント:
//   { type: "highlight", key }            光る項目が変わった
//   { type: "confirmStarted", key }       確認に入った
//   { type: "confirmed", key }            「はい」で確定した（送信や読み上げは呼び出し側）
//   { type: "confirmCancelled", reason }  reason: no / timeout
//   { type: "paused", reason }            reason: selected / idle
//   { type: "resumed" }                   休止から戻った
//
// 時計は「開眼（eyePhase が open）を続けて見ていた時間」だけ進む。
// 前の tick と今の tick の両方が開眼だった区間だけを数えるので、
// 閉眼中・顔なし・準備中・安定待ちなどの間と、tick が途切れた間は、残り時間のまま止まる。
// 目を閉じたことを受け取った tick の区間も数えない（閉じた目で固定した候補を、
// 同じ tick の時間切れで取り消さないため）。
// state.generation は画面の状態（mode）が変わるたびに進む。光る項目が移るだけでは進まない。
//
// blink_switch とつなぐ時の呼び出し順（この順を守ること。spec/javascript/blink_scan_integration.test.mjs）:
//   1. フレームを撮る時に、その時点の highlightedKey(state) と state.generation をフレームに付ける
//   2. 結果が届いたら stepBlinkSwitch（currentGeneration は今の state.generation）
//   3. 出てきた select イベントを、その場で stepScan の select へ渡す
//   4. 最後に stepScan の tick（eyePhase は 2. のあとの blink_switch の phase）
// 先に tick を呼ぶと、届いたばかりの閉じた目を知らないまま時計が進み、
// 項目の切り替わりや時間切れが先に起きてしまう。フレームが届かない間の tick は、最後に分かっている phase で呼ぶ。
//
// 用語: ここの「休止（paused）」は、スキャンを止めて長いまばたきを待つ画面の状態。
// blink_switch の「休憩（rest）」は、目を長く閉じたままなので決定しないという判定の状態で、別のもの。
// 休憩になってもスキャンは休止にならず、開眼に戻れば残り時間から続く。

import { FIXED } from "./config.js"

export const CONFIRM_NO = "confirm:no"
export const CONFIRM_YES = "confirm:yes"
const CONFIRM_KEYS = [CONFIRM_NO, CONFIRM_YES]

// items: [{ key, kind? }]。kind が "pause" の項目は「休止」。空や key の重なりがあれば始めない。
export function startScan(items, settings) {
  if (!Array.isArray(items) || items.length === 0) return { ok: false, error: "emptyItems" }
  const keys = items.map((item) => item?.key)
  const valid = keys.every((key) => typeof key === "string" && key !== "" && !CONFIRM_KEYS.includes(key))
  if (!valid || new Set(keys).size !== keys.length) return { ok: false, error: "invalidItems" }

  const state = toScanning({ items, generation: -1, lastTickAt: null, wasOpen: false }, settings)
  return { ok: true, state }
}

export function highlightedKey(state) {
  if (state.mode === "scanning") return state.items[state.index].key
  if (state.mode === "confirming" && state.index >= 0) return CONFIRM_KEYS[state.index]
  return null
}

export function stepScan(state, input, settings) {
  const before = highlightedKey(state)
  const events = []
  const next = input.type === "select"
    ? onSelect[state.mode](state, input.key, settings, events)
    : onTick(state, input, settings, events)
  const after = highlightedKey(next)
  if (after !== before && after !== null) events.push({ type: "highlight", key: after })
  return { state: next, events }
}

function firstStepMs(settings) {
  return settings.stepMs * settings.firstStepRatio
}

// mode を変える時は必ずここを通す（世代を進め、時計を止める）
function enter(state, fields) {
  return { ...state, pendingKey: null, ...fields, generation: state.generation + 1, wasOpen: false }
}

function toScanning(state, settings) {
  return enter(state, { mode: "scanning", index: 0, rounds: 0, remainingMs: firstStepMs(settings) })
}

// index -1 は「まだ何も光らせていない」。安定待ちが明けて開眼を見てから「いいえ」を光らせる。
function toConfirming(state, key, settings) {
  return enter(state, { mode: "confirming", pendingKey: key, index: -1, rounds: 0, remainingMs: settings.stepMs })
}

function toPaused(state) {
  return enter(state, { mode: "paused", index: 0, rounds: 0, remainingMs: 0 })
}

const onSelect = {
  scanning(state, key, settings, events) {
    const item = state.items.find((candidate) => candidate.key === key)
    if (!item) return state
    if (item.kind === "pause") {
      events.push({ type: "paused", reason: "selected" })
      return toPaused(state)
    }
    events.push({ type: "confirmStarted", key })
    return toConfirming(state, key, settings)
  },

  confirming(state, key, settings, events) {
    if (key === CONFIRM_YES) {
      events.push({ type: "confirmed", key: state.pendingKey })
      return enter(state, { mode: "finished" })
    }
    if (key === CONFIRM_NO) {
      events.push({ type: "confirmCancelled", reason: "no" })
      return toScanning(state, settings)
    }
    return state
  },

  // 休止中は何も光っていないので、どの key の決定でも「戻る」合図として扱う
  paused(state, _key, settings, events) {
    events.push({ type: "resumed" })
    return toScanning(state, settings)
  },

  finished(state) {
    return state
  }
}

function onTick(state, { now, eyePhase }, settings, events) {
  // 有限の数値でない時刻は無視する（覚えてしまうと、そのあとの間隔が計算できず時計が止まったままになる）
  if (typeof now !== "number" || !Number.isFinite(now)) return state
  if (state.lastTickAt !== null && now < state.lastTickAt) return state
  const isOpen = eyePhase === "open"
  const gap = state.lastTickAt === null ? 0 : now - state.lastTickAt
  const elapsed = state.wasOpen && isOpen && gap <= FIXED.maxFrameGapMs ? gap : 0
  const ticked = { ...state, lastTickAt: now, wasOpen: isOpen }

  if (state.mode === "scanning") return advanceScan(ticked, elapsed, settings, events)
  if (state.mode === "confirming") return advanceConfirm(ticked, elapsed, isOpen, settings, events)
  return ticked
}

function advanceScan(state, elapsed, settings, events) {
  const remainingMs = state.remainingMs - elapsed
  if (remainingMs > 0) return { ...state, remainingMs }

  const index = (state.index + 1) % state.items.length
  const rounds = index === 0 ? state.rounds + 1 : state.rounds
  if (index === 0 && rounds >= settings.autoPauseRounds) {
    events.push({ type: "paused", reason: "idle" })
    return toPaused(state)
  }
  const duration = index === 0 ? firstStepMs(settings) : settings.stepMs
  return { ...state, index, rounds, remainingMs: remainingMs + duration }
}

function advanceConfirm(state, elapsed, isOpen, settings, events) {
  if (state.index < 0) return isOpen ? { ...state, index: 0 } : state

  const remainingMs = state.remainingMs - elapsed
  if (remainingMs > 0) return { ...state, remainingMs }

  const index = (state.index + 1) % CONFIRM_KEYS.length
  const rounds = index === 0 ? state.rounds + 1 : state.rounds
  if (index === 0 && rounds >= settings.confirmRounds) {
    events.push({ type: "confirmCancelled", reason: "timeout" })
    return toScanning(state, settings)
  }
  return { ...state, index, rounds, remainingMs: remainingMs + settings.stepMs }
}
