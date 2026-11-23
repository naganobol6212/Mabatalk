// blink_switch（まばたき判定）と scan_sequencer（スキャン順）を、公開されている入口だけでつないだテスト。
// 画面側がつなぐ時と同じ順番で呼ぶ（scan_sequencer.js の先頭に書いた決まり）:
//   フレームが届く → stepBlinkSwitch → 出てきた select を stepScan へ → stepScan の tick
import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULTS } from "../../app/javascript/blink/config.js"
import { createBlinkSwitch, stepBlinkSwitch } from "../../app/javascript/blink/blink_switch.js"
import {
  CONFIRM_NO,
  CONFIRM_YES,
  highlightedKey,
  startScan,
  stepScan
} from "../../app/javascript/blink/scan_sequencer.js"

const SETTINGS = { ...DEFAULTS, closeThreshold: 0.6, openThreshold: 0.25 }
const ITEMS = [{ key: "a" }, { key: "b" }, { key: "c" }, { key: "pause", kind: "pause" }]
const OPEN = 0.05
const CLOSED = 0.9
const FACE = { x: 0.5, y: 0.5, size: 0.3 }
const FRAME_MS = 50

function driver() {
  let blink = createBlinkSwitch()
  let scan = startScan(ITEMS, SETTINGS).state
  let seq = 0
  const events = []
  const d = {
    events,
    get phase() { return blink.phase },
    get mode() { return scan.mode },
    get highlighted() { return highlightedKey(scan) },
    // 撮影: その時に光っている項目と画面の世代を付けたフレームを作るだけ（判定はまだ進めない）
    capture(capturedAt, score) {
      return {
        capturedAt,
        seq: seq++,
        generation: scan.generation,
        highlightedKey: highlightedKey(scan),
        faceDetected: true,
        leftScore: score,
        rightScore: score,
        face: FACE
      }
    },
    // 到着: 撮っておいたフレームの結果が now に届いた。
    // stepBlinkSwitch → 出てきた select を stepScan へ → stepScan の tick の順。
    deliver(frame, now) {
      const judged = stepBlinkSwitch(blink, { type: "frame", now, currentGeneration: scan.generation, frame }, SETTINGS)
      blink = judged.state
      events.push(...judged.events)
      for (const event of judged.events) {
        if (event.type !== "select") continue
        const selected = stepScan(scan, { type: "select", now, key: event.key }, SETTINGS)
        scan = selected.state
        events.push(...selected.events)
      }
      d.tickScan(now)
    },
    // フレームが届かない時の tick: 先に stepBlinkSwitch の見張り tick → その戻りの phase で stepScan の tick。
    tick(now) {
      const watched = stepBlinkSwitch(blink, { type: "tick", now, currentGeneration: scan.generation }, SETTINGS)
      blink = watched.state
      events.push(...watched.events)
      d.tickScan(now)
    },
    tickScan(now) {
      const ticked = stepScan(scan, { type: "tick", now, eyePhase: blink.phase }, SETTINGS)
      scan = ticked.state
      events.push(...ticked.events)
    },
    // 撮ってすぐ（latency ミリ秒後に）届く。撮影と到着のあいだに別の入力が無い時の近道。
    frame(capturedAt, score, latency = 0) {
      d.deliver(d.capture(capturedAt, score), capturedAt + latency)
    },
    run(from, to, score) {
      for (let t = from; t <= to; t += FRAME_MS) d.frame(t, score)
    },
    // 目を開けたまま、条件が成り立つまで 50ms ごとに進める。成り立った時刻を返す。
    openUntil(from, condition) {
      for (let t = from; t <= from + 60000; t += FRAME_MS) {
        d.frame(t, OPEN)
        if (condition()) return t
      }
      throw new Error("条件が成り立たないまま 60 秒たった")
    },
    count(type) { return events.filter((e) => e.type === type).length },
    last(type) { return events.filter((e) => e.type === type).at(-1) }
  }
  return d
}

// 「a」を長いまばたきで選び、確認の「いいえ」が光り始めた時刻を返す。
function confirmingA(d) {
  d.run(0, 300, OPEN)
  assert.equal(d.phase, "open")
  assert.equal(d.highlighted, "a")
  d.run(350, 1150, CLOSED)
  d.frame(1200, OPEN)
  assert.deepEqual(d.last("confirmStarted"), { type: "confirmStarted", key: "a" })
  return d.openUntil(1250, () => d.highlighted === CONFIRM_NO)
}

test("つないだ時: 長いまばたきで項目を選び、「はい」も長いまばたきで選ぶと、その項目が確定する", () => {
  const d = driver()
  const t = confirmingA(d)
  const yesAt = d.openUntil(t + FRAME_MS, () => d.highlighted === CONFIRM_YES)
  d.run(yesAt + 50, yesAt + 850, CLOSED)
  d.frame(yesAt + 900, OPEN)
  assert.deepEqual(d.last("confirmed"), { type: "confirmed", key: "a" })
  assert.equal(d.count("confirmed"), 1)
  assert.equal(d.mode, "finished")
})

test("つないだ時: 確認の期限まで残り 50ms で閉じ、その結果が 10ms おくれて期限の時刻に届いても、「はい」を決定できる", () => {
  const d = driver()
  const t = confirmingA(d)
  // 確認は いいえ→はい を 2 周（8000ms）。t+7950 では 2 周目の「はい」で、残り 50ms
  d.run(t + FRAME_MS, t + 7950, OPEN)
  assert.equal(d.highlighted, CONFIRM_YES)
  // t+7990 に閉じたフレームが、期限ちょうどの t+8000 に届く
  d.frame(t + 7990, CLOSED, 10)
  assert.equal(d.phase, "closing")
  assert.equal(d.mode, "confirming", "閉じた目を受け取った時は、確認の期限を進めない")
  d.run(t + 8040, t + 8790, CLOSED)
  d.frame(t + 8840, OPEN)
  assert.equal(d.count("cancel"), 0)
  assert.equal(d.count("confirmCancelled"), 0)
  assert.deepEqual(d.last("confirmed"), { type: "confirmed", key: "a" })
})

test("つないだ時: 自動休止まで残り 50ms で閉じた長いまばたきは、光っていた項目の決定になる", () => {
  const d = driver()
  d.run(0, 300, OPEN)
  const lastAt = d.openUntil(350, () => d.highlighted === "pause" && d.count("highlight") === 11)
  // 3 周目の最後の項目（2000ms）の残り 50ms まで開けておく
  d.run(lastAt + FRAME_MS, lastAt + 1950, OPEN)
  assert.equal(d.mode, "scanning")
  d.frame(lastAt + 1990, CLOSED, 10)
  d.run(lastAt + 2040, lastAt + 2790, CLOSED)
  d.frame(lastAt + 2840, OPEN)
  assert.equal(d.count("cancel"), 0)
  assert.deepEqual(d.last("select"), { type: "select", key: "pause" })
  assert.deepEqual(d.last("paused"), { type: "paused", reason: "selected" })
})

test("つないだ時: ふつうのまばたき（300ms）では何も選ばれず、スキャンは残り時間から続く", () => {
  const d = driver()
  d.run(0, 300, OPEN)
  d.run(350, 650, CLOSED)
  d.frame(700, OPEN)
  assert.equal(d.count("select"), 0)
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
})

test("つないだ時: フレームが届かなくなって 500ms たつと準備中へ戻ってスキャンが止まり、開眼を確かめ直すと残り時間から再開する", () => {
  const d = driver()
  d.run(0, 300, OPEN)
  assert.equal(d.phase, "open")
  // 300ms を最後にフレームが届かない。見張りの tick だけが 50ms ごとに来る
  for (let t = 350; t <= 750; t += FRAME_MS) d.tick(t)
  d.tick(799)
  assert.equal(d.phase, "open", "最後に届いてから 499ms は、まだ開眼のまま")
  d.tick(800)
  assert.equal(d.phase, "arming", "500ms ちょうどで準備中へ戻る")
  // 「a」は 300ms から 3000ms 光る予定だった。止まっていなければ 3300ms で「b」へ移る
  for (let t = 850; t <= 4000; t += FRAME_MS) d.tick(t)
  assert.equal(d.phase, "arming")
  assert.equal(d.highlighted, "a", "準備中はスキャンの時計が止まる")
  assert.equal(d.count("highlight"), 0)
  // フレームが戻る。開眼を 300ms 続けて見て（4350ms）から、時計がまた進む
  d.run(4050, 4350, OPEN)
  assert.equal(d.phase, "open")
  // 止まるまでに 499ms 使ったので、残りは 2501ms。4350 + 2501 = 6851ms で「b」へ移る
  d.run(4400, 6850, OPEN)
  assert.equal(d.highlighted, "a")
  d.frame(6900, OPEN)
  assert.equal(d.highlighted, "b")
})
