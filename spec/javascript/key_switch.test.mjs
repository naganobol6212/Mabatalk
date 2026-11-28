// キー・タップを「長いまばたき 1 回」として扱う入力源（key_switch）のテスト。
import { test } from "node:test"
import assert from "node:assert/strict"
import { createKeySource, createKeySwitch, keyIntent, stepKeySwitch } from "../../app/javascript/blink/key_switch.js"

const SETTINGS = { refractoryMs: 800 }

function driver() {
  let state = createKeySwitch()
  const events = []
  const apply = (input) => {
    const result = stepKeySwitch(state, input, SETTINGS)
    state = result.state
    events.push(...result.events)
    return result.events
  }
  return {
    events,
    get phase() { return state.phase },
    press(now, highlightedKey = "a") { return apply({ type: "press", now, highlightedKey }) },
    tick(now) { return apply({ type: "tick", now }) }
  }
}

test("最初は受付中（open）。押すと、その時に光っていた項目の決定が 1 回出て、安定待ち（refractory）に入る", () => {
  const d = driver()
  assert.equal(d.phase, "open")
  assert.deepEqual(d.press(1000, "b"), [{ type: "select", key: "b" }])
  assert.equal(d.phase, "refractory")
})

test("安定待ちのあいだ（800ms 未満）に押しても、決定は出ない", () => {
  const d = driver()
  d.press(1000)
  assert.deepEqual(d.press(1100), [])
  d.tick(1799)
  assert.equal(d.phase, "refractory")
  assert.deepEqual(d.press(1799), [])
  assert.equal(d.events.length, 1)
})

test("安定待ちは 800ms ちょうどで明け、また押せる。明ける時刻は最初の決定から数える（途中で押しても延びない）", () => {
  const d = driver()
  d.press(1000)
  d.press(1500)
  d.tick(1800)
  assert.equal(d.phase, "open")
  assert.deepEqual(d.press(1800, "c"), [{ type: "select", key: "c" }])
})

test("tick が来ないまま 800ms たってから押しても、決定になる", () => {
  const d = driver()
  d.press(1000)
  assert.deepEqual(d.press(1800, "b"), [{ type: "select", key: "b" }])
})

test("何も光っていない時（休止中）に押すと、key が null の決定になる", () => {
  const d = driver()
  assert.deepEqual(d.press(1000, null), [{ type: "select", key: null }])
})

test("時刻が有限の数値でない入力は捨てる（状態も変えない）", () => {
  for (const bad of [NaN, Infinity, undefined, null, "1000"]) {
    const d = driver()
    assert.deepEqual(d.press(bad), [])
    assert.equal(d.phase, "open")
    d.press(1000)
    d.tick(bad)
    assert.equal(d.phase, "refractory")
  }
})

test("入力源（createKeySource）: 押した結果を、画面へ渡す形 { now, phase, events } で返す。reset で受付中に戻る", () => {
  const source = createKeySource(SETTINGS)
  assert.deepEqual(source.tick(0), { now: 0, phase: "open", events: [] })
  assert.deepEqual(source.press(100, "a"), { now: 100, phase: "refractory", events: [{ type: "select", key: "a" }] })
  assert.deepEqual(source.press(200, "a"), { now: 200, phase: "refractory", events: [] })
  source.reset()
  assert.deepEqual(source.press(300, "b"), { now: 300, phase: "refractory", events: [{ type: "select", key: "b" }] })
})

const key = (fields) => ({ key: " ", repeat: false, altKey: false, ctrlKey: false, metaKey: false, shiftKey: false, onControl: false, ...fields })

test("キーの扱い: Space と Enter は「押した」になる", () => {
  assert.equal(keyIntent(key({ key: " " })), "press")
  assert.equal(keyIntent(key({ key: "Enter" })), "press")
})

test("キーの扱い: 押しっぱなしで出るくり返し（repeat）は、押したことにしない（画面が動かないよう、キーは受け取る）", () => {
  assert.equal(keyIntent(key({ key: " ", repeat: true })), "swallow")
  assert.equal(keyIntent(key({ key: "Enter", repeat: true })), "swallow")
})

test("キーの扱い: フォーカスがボタン・リンク・入力欄にある時は、スキャン入力にしない（ふつうに押せる）", () => {
  assert.equal(keyIntent(key({ key: " ", onControl: true })), "ignore")
  assert.equal(keyIntent(key({ key: "Enter", onControl: true })), "ignore")
  assert.equal(keyIntent(key({ key: " ", onControl: true, repeat: true })), "ignore")
})

test("キーの扱い: Space / Enter 以外と、修飾キー（Ctrl・Alt・Cmd）付きは、スキャン入力にしない", () => {
  for (const other of ["a", "Tab", "Escape", "ArrowDown", "Shift"]) assert.equal(keyIntent(key({ key: other })), "ignore")
  assert.equal(keyIntent(key({ ctrlKey: true })), "ignore")
  assert.equal(keyIntent(key({ altKey: true })), "ignore")
  assert.equal(keyIntent(key({ key: "Enter", metaKey: true })), "ignore")
})

test("キーの扱い: Shift 付きも、スキャン入力にしない（Shift+Space は上へのスクロール。くり返しも受け取らない）", () => {
  assert.equal(keyIntent(key({ key: " ", shiftKey: true })), "ignore")
  assert.equal(keyIntent(key({ key: "Enter", shiftKey: true })), "ignore")
  assert.equal(keyIntent(key({ key: " ", shiftKey: true, repeat: true })), "ignore")
})
