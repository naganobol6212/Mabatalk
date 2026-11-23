import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULTS } from "../../app/javascript/blink/config.js"
import {
  CONFIRM_NO,
  CONFIRM_YES,
  highlightedKey,
  startScan,
  stepScan
} from "../../app/javascript/blink/scan_sequencer.js"

const ITEMS = [{ key: "a" }, { key: "b" }, { key: "c" }, { key: "pause", kind: "pause" }]
const TICK_MS = 50
// 1周 = 先頭 3000ms + 残り3項目 × 2000ms
const ROUND_MS = 9000

function driver(items = ITEMS, settings = DEFAULTS) {
  const started = startScan(items, settings)
  assert.equal(started.ok, true)
  let state = started.state
  const events = []
  const apply = (input) => {
    const result = stepScan(state, input, settings)
    state = result.state
    events.push(...result.events)
    return result.events
  }
  const d = {
    events,
    get mode() { return state.mode },
    get generation() { return state.generation },
    get highlighted() { return highlightedKey(state) },
    tick(now, eyePhase = "open") { return apply({ type: "tick", now, eyePhase }) },
    // from から to まで 50ms ごとに時計を進める（両端を含む）
    run(from, to, eyePhase = "open") {
      for (let t = from; t <= to; t += TICK_MS) d.tick(t, eyePhase)
    },
    select(now, key) { return apply({ type: "select", now, key }) },
    count(type) { return events.filter((e) => e.type === type).length },
    last(type) { return events.filter((e) => e.type === type).at(-1) }
  }
  return d
}

test("項目が空なら始めない", () => {
  assert.deepEqual(startScan([], DEFAULTS), { ok: false, error: "emptyItems" })
  assert.deepEqual(startScan(null, DEFAULTS), { ok: false, error: "emptyItems" })
})

test("key が無い・重なっている項目リストでは始めない", () => {
  assert.deepEqual(startScan([{ key: "a" }, {}], DEFAULTS), { ok: false, error: "invalidItems" })
  assert.deepEqual(startScan([{ key: "a" }, { key: "a" }], DEFAULTS), { ok: false, error: "invalidItems" })
})

test("始めた直後は先頭の項目が光る", () => {
  const d = driver()
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
})

test("先頭は 3000ms、そのあとは 2000ms ごとに次の項目が光る", () => {
  const d = driver()
  d.run(0, 2950)
  assert.equal(d.highlighted, "a")
  d.tick(3000)
  assert.equal(d.highlighted, "b")
  d.run(3050, 4950)
  assert.equal(d.highlighted, "b")
  d.tick(5000)
  assert.equal(d.highlighted, "c")
  d.run(5050, 7000)
  assert.equal(d.highlighted, "pause")
})

test("2周目の先頭も 1.5 倍の長さで光る", () => {
  const d = driver()
  d.run(0, ROUND_MS)
  assert.equal(d.highlighted, "a")
  d.run(ROUND_MS + 50, ROUND_MS + 2950)
  assert.equal(d.highlighted, "a")
  d.tick(ROUND_MS + 3000)
  assert.equal(d.highlighted, "b")
})

test("光る項目が変わるたびに highlight イベントを出す", () => {
  const d = driver()
  d.run(0, 2950)
  assert.equal(d.count("highlight"), 0)
  assert.deepEqual(d.tick(3000), [{ type: "highlight", key: "b" }])
})

for (const phase of ["closing", "noface"]) {
  test(`${phase} の間は残り時間だけ止まり、目が開くと続きから再開する`, () => {
    const d = driver()
    d.run(0, 1000)
    // 1050 の時点で閉じた。1000→1050 の 50ms は開いていた時間として数える
    d.run(1050, 1600, phase)
    d.run(1650, 3550)
    assert.equal(d.highlighted, "a", "600ms 止まっていたので 3000 では切り替わらない")
    d.tick(3600)
    assert.equal(d.highlighted, "b")
  })
}

test("目を閉じたことを受け取った tick では、時計を進めない（残り 50ms で閉じても切り替わらない）", () => {
  const d = driver()
  d.run(0, 2950)
  d.tick(3000, "closing")
  assert.equal(d.highlighted, "a", "閉じた目が届いた tick の 50ms は数えない")
  d.run(3050, 3800, "closing")
  d.tick(3850, "refractory")
  d.tick(3900)
  assert.equal(d.highlighted, "a")
  d.tick(3950)
  assert.equal(d.highlighted, "b", "開眼に戻ってから残りの 50ms で切り替わる")
})

test("3周だれも選ばなければ自動で休止する", () => {
  const d = driver()
  d.run(0, ROUND_MS * 3 - 50)
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "pause")
  d.tick(ROUND_MS * 3)
  assert.equal(d.mode, "paused")
  assert.equal(d.highlighted, null)
  assert.deepEqual(d.last("paused"), { type: "paused", reason: "idle" })
})

test("休止中は時計が進まず、長いまばたき1回でスキャンに戻る（休止明けの先頭は 3000ms）", () => {
  const d = driver()
  d.run(0, ROUND_MS * 3)
  d.run(ROUND_MS * 3 + 50, 60000)
  assert.equal(d.mode, "paused")
  d.select(60000, null)
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.count("resumed"), 1)
  d.run(60050, 60800, "refractory")
  d.run(60850, 63800)
  assert.equal(d.highlighted, "a")
  d.tick(63850)
  assert.equal(d.highlighted, "b")
})

test("「休止」項目を決定すると休止する", () => {
  const d = driver()
  d.run(0, 7500)
  assert.equal(d.highlighted, "pause")
  d.select(7500, "pause")
  assert.equal(d.mode, "paused")
  assert.deepEqual(d.last("paused"), { type: "paused", reason: "selected" })
  assert.equal(d.count("confirmStarted"), 0)
})

// b を決定して確認に入り、安定待ち（refractory）が明けるところまで進める。
// 明けて最初に開眼を見た時刻を返す。
function confirmingB(d) {
  d.run(0, 3500)
  assert.equal(d.highlighted, "b")
  d.select(3500, "b")
  d.run(3550, 4300, "refractory")
  return 4350
}

test("決定すると確認に入り、安定待ちの間は何も光らない", () => {
  const d = driver()
  d.run(0, 3500)
  d.select(3500, "b")
  assert.equal(d.mode, "confirming")
  assert.deepEqual(d.last("confirmStarted"), { type: "confirmStarted", key: "b" })
  assert.equal(d.highlighted, null)
  d.run(3550, 4300, "refractory")
  assert.equal(d.highlighted, null)
})

test("確認は安定待ちのあと「いいえ」から光り、2000ms で「はい」に移る", () => {
  const d = driver()
  const t = confirmingB(d)
  d.tick(t)
  assert.equal(d.highlighted, CONFIRM_NO)
  d.run(t + 50, t + 1950)
  assert.equal(d.highlighted, CONFIRM_NO)
  d.tick(t + 2000)
  assert.equal(d.highlighted, CONFIRM_YES)
})

test("「はい」を決定すると、選んだ項目の確定イベントを1回出して止まる", () => {
  const d = driver()
  const t = confirmingB(d)
  d.run(t, t + 2500)
  d.select(t + 2500, CONFIRM_YES)
  assert.deepEqual(d.last("confirmed"), { type: "confirmed", key: "b" })
  assert.equal(d.mode, "finished")
  assert.equal(d.highlighted, null)
  d.run(t + 2550, t + 20000)
  d.select(t + 20000, CONFIRM_YES)
  assert.equal(d.count("confirmed"), 1)
  assert.equal(d.mode, "finished")
})

test("「いいえ」を決定するとスキャンの先頭へ戻る（確定しない）", () => {
  const d = driver()
  const t = confirmingB(d)
  d.run(t, t + 500)
  d.select(t + 500, CONFIRM_NO)
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.count("confirmed"), 0)
  assert.deepEqual(d.last("confirmCancelled"), { type: "confirmCancelled", reason: "no" })
})

test("確認で2周だれも選ばなければスキャンの先頭へ戻る", () => {
  const d = driver()
  const t = confirmingB(d)
  d.run(t, t + 7950)
  assert.equal(d.mode, "confirming")
  assert.equal(d.highlighted, CONFIRM_YES)
  d.tick(t + 8000)
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.count("confirmed"), 0)
  assert.deepEqual(d.last("confirmCancelled"), { type: "confirmCancelled", reason: "timeout" })
})

test("確認から戻ったあとは、3周の数え直しになる", () => {
  const d = driver()
  d.run(0, ROUND_MS * 2 + 3500)
  d.select(ROUND_MS * 2 + 3500, "b")
  const t = ROUND_MS * 2 + 3550
  d.tick(t)
  d.select(t + 500, CONFIRM_NO)
  d.run(t + 550, t + 550 + ROUND_MS * 2)
  assert.equal(d.mode, "scanning", "戻ってから2周ではまだ休止しない")
})

test("世代番号は画面の状態が変わる時だけ進み、光る項目が移るだけでは進まない", () => {
  const d = driver()
  const g0 = d.generation
  d.run(0, 3500)
  assert.equal(d.generation, g0)
  d.select(3500, "b")
  const g1 = d.generation
  assert.notEqual(g1, g0)
  d.run(3550, 6000)
  assert.equal(d.generation, g1, "いいえ→はい と移るだけでは進まない")
  d.select(6000, CONFIRM_NO)
  const g2 = d.generation
  assert.notEqual(g2, g1)
  d.run(6050, 6050 + 7500)
  d.select(6050 + 7500, "pause")
  assert.notEqual(d.generation, g2)
})

test("今の画面に無い key の決定は無視する", () => {
  const d = driver()
  d.run(0, 3500)
  const events = d.select(3500, CONFIRM_YES)
  assert.deepEqual(events, [])
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "b")
  d.select(3500, null)
  assert.equal(d.mode, "scanning")
})

test("確認中にスキャン項目の key で決定が届いても確定しない", () => {
  const d = driver()
  const t = confirmingB(d)
  d.run(t, t + 2500)
  d.select(t + 2500, "b")
  assert.equal(d.mode, "confirming")
  assert.equal(d.count("confirmed"), 0)
})

test("tick の間隔が 250ms を超えた分は、見ていなかった時間として進めない", () => {
  const d = driver()
  d.run(0, 1000)
  d.tick(11000)
  assert.equal(d.highlighted, "a")
  d.run(11050, 12950)
  assert.equal(d.highlighted, "a")
  d.tick(13000)
  assert.equal(d.highlighted, "b")
})

test("tick が切り替わりの時刻をまたいでも、次の項目の持ち時間はずれない", () => {
  const d = driver()
  // 240ms ごとの tick。3000 をまたぐのは 3120、5000 をまたぐのは 5040
  for (let t = 0; t <= 2880; t += 240) d.tick(t)
  assert.equal(d.highlighted, "a")
  d.tick(3120)
  assert.equal(d.highlighted, "b")
  for (let t = 3360; t <= 4800; t += 240) d.tick(t)
  assert.equal(d.highlighted, "b")
  d.tick(5040)
  assert.equal(d.highlighted, "c")
})

test("時刻が逆戻りした tick は無視する", () => {
  const d = driver()
  d.run(0, 1000)
  d.tick(500)
  d.run(1050, 2950)
  assert.equal(d.highlighted, "a")
  d.tick(3000)
  assert.equal(d.highlighted, "b")
})

test("入力の状態オブジェクトを書き換えない", () => {
  const started = startScan(ITEMS, DEFAULTS)
  const frozen = Object.freeze({ ...started.state })
  const result = stepScan(frozen, { type: "tick", now: 0, eyePhase: "open" }, DEFAULTS)
  assert.equal(highlightedKey(frozen), "a")
  assert.equal(result.state.mode, "scanning")
})
