// blink_switch（まばたき判定）と scan_sequencer（スキャン順）を、公開されている入口だけでつないだテスト。
// 画面側がつなぐ時と同じ順番で呼ぶ（scan_sequencer.js の先頭に書いた決まり）:
//   結果が届いた時: stepBlinkSwitch（frame）→ 出てきた select を stepScan へ → stepScan の tick
//   届かない時:     stepBlinkSwitch（tick）→ その戻りの phase で stepScan の tick
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
  const inFlight = []
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
    // 結果がおくれて届く時の 1 コマ: now までに届く結果があれば順に到着、無ければ tick。
    // そのあと score の目を撮り、latency ミリ秒後に届くよう預ける（score を渡さなければ撮らない）。
    beat(now, score, latency = 0) {
      const arrived = inFlight.filter((flying) => flying.arriveAt <= now)
      inFlight.splice(0, arrived.length)
      if (arrived.length === 0) d.tick(now)
      for (const flying of arrived) d.deliver(flying.frame, now)
      if (score !== undefined) inFlight.push({ frame: d.capture(now, score), arriveAt: now + latency })
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
  // 「a」の 3000ms は、閉じる前には 1 コマも使っていない（開眼と分かった 300ms の次が、もう閉眼）。
  // 開眼に戻った 700ms から残り 3000ms を数えるので、3700ms で「b」へ移る
  d.run(750, 3650, OPEN)
  assert.equal(d.highlighted, "a")
  d.frame(3700, OPEN)
  assert.equal(d.highlighted, "b")
  assert.equal(d.count("select"), 0)
})

test("つないだ時: 保持時間（800ms）に届いたフレームがもう開眼でも、合図・決定・確認開始が 1 回ずつ順に出る", () => {
  const d = driver()
  d.run(0, 300, OPEN)
  // 350ms から閉じ、1100ms（750ms 目）まで閉眼。次の 1150ms（800ms 目）のフレームは開眼
  d.run(350, 1100, CLOSED)
  assert.equal(d.count("holdReached"), 0)
  d.frame(1150, OPEN)
  const types = ["holdReached", "select", "confirmStarted"]
  assert.deepEqual(d.events.filter((e) => types.includes(e.type)), [
    { type: "holdReached", key: "a" },
    { type: "select", key: "a" },
    { type: "confirmStarted", key: "a" }
  ])
  assert.equal(d.mode, "confirming")
  // そのあと開眼が続いても、同じまばたきからもう 1 回は出ない
  d.run(1200, 1500, OPEN)
  assert.equal(d.count("holdReached"), 1)
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("confirmStarted"), 1)
})

// 50ms ごとに撮った結果が、150 / 200 / 250 / 200ms … とばらついておくれて届く（届く順は撮った順のまま）
const LATENCIES = [150, 200, 250, 200]
const latencyAt = (t) => LATENCIES[(t / FRAME_MS) % LATENCIES.length]

test("つないだ時: 結果が 150〜250ms おくれて届き、そのあいだに光る項目が移っても、長いまばたきは撮った時に光っていた項目の決定になる", () => {
  const d = driver()
  // 300ms に撮った開眼が 550ms に届いて開眼と分かる。「a」は 550ms から 3000ms 光り、3550ms で「b」へ移る。
  // 3450ms（まだ「a」）に目を閉じたが、その結果が届くのは 3650ms（もう「b」）
  for (let t = 0; t <= 3400; t += FRAME_MS) d.beat(t, OPEN, latencyAt(t))
  assert.equal(d.highlighted, "a")
  for (let t = 3450; t <= 3600; t += FRAME_MS) d.beat(t, CLOSED, latencyAt(t))
  assert.equal(d.phase, "open", "閉じた結果は、まだ届いていない")
  assert.equal(d.highlighted, "b")
  d.beat(3650, CLOSED, latencyAt(3650))
  assert.equal(d.phase, "closing")
  // 4250ms まで閉じ（800ms）、4300ms に開ける。その結果は 4550ms に届く
  for (let t = 3700; t <= 4250; t += FRAME_MS) d.beat(t, CLOSED, latencyAt(t))
  for (let t = 4300; t <= 4500; t += FRAME_MS) d.beat(t, OPEN, latencyAt(t))
  assert.equal(d.count("select"), 0)
  d.beat(4550)
  assert.deepEqual(d.last("select"), { type: "select", key: "a" })
  assert.deepEqual(d.last("confirmStarted"), { type: "confirmStarted", key: "a" })
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("cancel"), 0)
})

test("つないだ時: 結果が届く前の tick で確認が時間切れになったら、前の画面で撮った結果はあとから届いても捨てる", () => {
  const d = driver()
  const t = confirmingA(d)
  d.run(t + FRAME_MS, t + 7950, OPEN)
  assert.equal(d.highlighted, CONFIRM_YES)
  // 「はい」が光っている t+7990 に閉じた目を撮ったが、結果が届く前に t+8000 の tick が来る
  const late = d.capture(t + 7990, CLOSED)
  d.tick(t + 8000)
  assert.deepEqual(d.last("confirmCancelled"), { type: "confirmCancelled", reason: "timeout" })
  assert.equal(d.mode, "scanning")
  assert.equal(d.highlighted, "a")
  d.deliver(late, t + 8010)
  assert.deepEqual(d.events.at(-1), { type: "discard", reason: "generation" })
  assert.equal(d.phase, "open")
  assert.equal(d.count("confirmed"), 0)
  assert.equal(d.count("select"), 1, "決定は、最初に「a」を選んだ 1 回だけ")
})

// PR1 の限界（まだ直していない。画面につなぐ PR2 で直す）:
// 上の列の続き。前の画面の「はい」に向けて閉じた目が、時間切れのあとも閉じたままだと、
// 新しい画面で最初に届いた閉眼フレームから数え直され、同じ 1 回のまばたきが先頭の「a」の決定になる。
// 直す時の決まり: 画面が自動で切り替わったあとは、新しい画面で開眼を見るまで閉眼の始まりを受け付けない。
// 今はこのテストは落ちる（select が 2 回になる）ので todo にしてある。
test("つないだ時: 時間切れで画面が切り替わる前から閉じていた目は、新しい画面の項目の決定にならない", { todo: "PR2 で直す" }, () => {
  const d = driver()
  const t = confirmingA(d)
  d.run(t + FRAME_MS, t + 7950, OPEN)
  const late = d.capture(t + 7990, CLOSED)
  d.tick(t + 8000)
  d.deliver(late, t + 8010)
  d.run(t + 8040, t + 8790, CLOSED)
  d.frame(t + 8840, OPEN)
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("confirmStarted"), 1)
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
