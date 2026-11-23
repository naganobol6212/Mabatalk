import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULTS } from "../../app/javascript/blink/config.js"
import { createBlinkSwitch, stepBlinkSwitch } from "../../app/javascript/blink/blink_switch.js"

const SETTINGS = { ...DEFAULTS, closeThreshold: 0.6, openThreshold: 0.25 }
const OPEN = 0.05
const BETWEEN = 0.4
const CLOSED = 0.9
const FACE = { x: 0.5, y: 0.5, size: 0.3 }
const FRAME_MS = 50

// テスト用の運転席。フレームを時刻つきで流し、出てきたイベントをためる。
function driver(settings = SETTINGS) {
  let state = createBlinkSwitch()
  let seq = 0
  const events = []
  const apply = (input) => {
    const result = stepBlinkSwitch(state, input, settings)
    state = result.state
    events.push(...result.events)
    return result.events
  }
  const d = {
    events,
    get phase() { return state.phase },
    get state() { return state },
    feed(capturedAt, score, options = {}) {
      const { latency = 0, currentGeneration = 0, ...frame } = options
      return apply({
        type: "frame",
        now: capturedAt + latency,
        currentGeneration,
        frame: {
          capturedAt,
          seq: seq++,
          generation: 0,
          highlightedKey: "A",
          faceDetected: true,
          leftScore: score,
          rightScore: score,
          face: FACE,
          ...frame
        }
      })
    },
    run(from, to, score, options = {}) {
      for (let t = from; t <= to; t += FRAME_MS) d.feed(t, score, options)
    },
    tick(now, currentGeneration = 0) {
      return apply({ type: "tick", now, currentGeneration })
    },
    count(type) { return events.filter((e) => e.type === type).length },
    last(type) { return events.filter((e) => e.type === type).at(-1) }
  }
  return d
}

// 0〜300ms 目を開けて「開眼」になったところから始める。目を閉じるのは 350ms から。
function opened(settings = SETTINGS) {
  const d = driver(settings)
  d.run(0, 300, OPEN)
  assert.equal(d.phase, "open")
  return d
}

test("最初は顔なし。顔が映ると準備中になり、開いた目が 300ms 続いて初めて開眼になる", () => {
  const d = driver()
  assert.equal(d.phase, "noface")
  d.feed(0, OPEN)
  assert.equal(d.phase, "arming")
  d.run(50, 250, OPEN)
  assert.equal(d.phase, "arming")
  d.feed(300, OPEN)
  assert.equal(d.phase, "open")
})

test("準備中に目を閉じると、開眼の確認は数え直しになる", () => {
  const d = driver()
  d.run(0, 200, OPEN)
  d.feed(250, CLOSED)
  d.run(300, 550, OPEN)
  assert.equal(d.phase, "arming")
  d.feed(600, OPEN)
  assert.equal(d.phase, "open")
})

test("準備中にフレームが 250ms を超えて途切れたら、開眼の確認は数え直しになる", () => {
  const d = driver()
  d.run(0, 50, OPEN)
  d.feed(350, OPEN)
  assert.equal(d.phase, "arming", "途切れた間も開いていたとはみなさない")
  d.run(400, 600, OPEN)
  assert.equal(d.phase, "arming")
  d.feed(650, OPEN)
  assert.equal(d.phase, "open")
})

test("300ms のまばたきでは決定しない（候補を捨てて開眼に戻る）", () => {
  const d = opened()
  d.run(350, 650, CLOSED)
  assert.equal(d.phase, "closing")
  d.feed(700, OPEN)
  assert.equal(d.phase, "open")
  assert.equal(d.count("holdReached"), 0)
  assert.equal(d.count("select"), 0)
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "shortBlink", key: "A" })
})

test("800ms 閉じ続けた時点で holdReached、目を開いた瞬間に select を1回だけ出す", () => {
  const d = opened()
  d.run(350, 1100, CLOSED)
  assert.equal(d.count("holdReached"), 0, "750ms ではまだ")
  d.feed(1150, CLOSED)
  assert.deepEqual(d.last("holdReached"), { type: "holdReached", key: "A" })
  assert.equal(d.phase, "ready")
  d.run(1200, 1500, CLOSED)
  assert.equal(d.count("select"), 0, "閉じている間は決定しない")
  d.feed(1550, OPEN)
  assert.deepEqual(d.last("select"), { type: "select", key: "A" })
  assert.equal(d.phase, "refractory")
  d.run(1600, 3000, OPEN)
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("holdReached"), 1)
})

test("閉じてからちょうど 800ms のフレームで開いていたら、holdReached と select を1回ずつ出す", () => {
  const d = opened()
  d.run(350, 1100, CLOSED)
  assert.equal(d.count("holdReached"), 0, "最後の閉眼フレームは 750ms の時点")
  const events = d.feed(1150, OPEN)
  assert.deepEqual(events, [{ type: "holdReached", key: "A" }, { type: "select", key: "A" }])
  assert.equal(d.phase, "refractory")
  d.run(1200, 2500, OPEN)
  assert.equal(d.count("holdReached"), 1)
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("cancel"), 0)
})

test("閉じてから 799ms で開いたら、保持時間の前なので決定しない", () => {
  const d = opened()
  d.run(350, 1100, CLOSED)
  d.feed(1149, OPEN)
  assert.equal(d.phase, "open")
  assert.equal(d.count("holdReached"), 0)
  assert.equal(d.count("select"), 0)
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "shortBlink", key: "A" })
})

test("しきい値のあいだのスコアでは閉眼を始めない", () => {
  const d = opened()
  d.run(350, 1500, BETWEEN)
  assert.equal(d.phase, "open")
  assert.equal(d.count("holdReached"), 0)
})

test("閉眼中にしきい値のあいだへ戻っても、開きしきい値以下になるまでは閉じたままとして数える", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.run(650, 1150, BETWEEN)
  assert.equal(d.phase, "ready")
  d.run(1200, 1400, BETWEEN)
  assert.equal(d.count("select"), 0)
  d.feed(1450, SETTINGS.openThreshold)
  assert.equal(d.count("select"), 1)
})

test("閉じしきい値ちょうどのスコアは閉眼として扱う", () => {
  const d = opened()
  d.feed(350, SETTINGS.closeThreshold)
  assert.equal(d.phase, "closing")
})

test("安定待ちは 800ms たっただけでは解けず、開眼を確認して初めて開眼に戻る", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  assert.equal(d.phase, "refractory")
  d.run(1250, 1950, CLOSED)
  d.run(2000, 2100, CLOSED)
  assert.equal(d.phase, "refractory", "800ms たっても閉じたままなら解けない")
  d.feed(2150, OPEN)
  assert.equal(d.phase, "open")
  assert.equal(d.count("select"), 1, "安定待ちの間のまばたきでは決定しない")
})

test("安定待ちは 800ms たつ前に目を開けていても解けない", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  d.run(1250, 1950, OPEN)
  assert.equal(d.phase, "refractory")
  d.feed(2000, OPEN)
  assert.equal(d.phase, "open")
})

test("5000ms ちょうど閉じたままなら休憩になり、決定しない", () => {
  const d = opened()
  d.run(350, 5300, CLOSED)
  assert.equal(d.phase, "ready", "4950ms ではまだ決定待ち")
  d.feed(5350, CLOSED)
  assert.equal(d.phase, "rest")
  assert.deepEqual(d.last("rest"), { type: "rest", key: "A" })
  d.feed(5400, OPEN)
  assert.equal(d.phase, "arming", "休憩は目が開くと準備中へ")
  d.run(5450, 7000, OPEN)
  assert.equal(d.count("select"), 0)
})

test("閉じてから 5000ms ちょうどに開いたフレームが届いても、休憩を優先して決定しない", () => {
  const d = opened()
  d.run(350, 5300, CLOSED)
  d.feed(5350, OPEN)
  assert.equal(d.count("select"), 0)
  assert.equal(d.count("rest"), 1)
})

test("5000ms に届く前に開いたなら決定する（4990ms）", () => {
  const d = opened()
  d.run(350, 5300, CLOSED)
  d.feed(5340, OPEN)
  assert.equal(d.count("select"), 1)
  assert.equal(d.count("rest"), 0)
})

test("閉眼中に顔が1フレームでも消えたら取り消す。そのあと閉じ続けて開いても決定しない", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.feed(650, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "noface")
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "faceLost", key: "A" })
  d.run(700, 1600, CLOSED)
  d.run(1650, 1700, OPEN)
  assert.equal(d.count("holdReached"), 0)
  assert.equal(d.count("select"), 0)
})

test("決定待ちで顔が消えたら取り消す（開いても決定しない）", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  assert.equal(d.phase, "ready")
  d.feed(1200, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "noface")
  d.run(1250, 1700, OPEN)
  assert.equal(d.count("select"), 0)
})

test("開眼中の顔ロストは 300ms までは待ち、300ms を超えたら顔なしになる", () => {
  const d = opened()
  d.run(350, 650, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "open", "消えてから 300ms ちょうどはまだ開眼")
  d.feed(700, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "noface")
})

test("顔ロストが 300ms 以内に戻れば開眼のまま", () => {
  const d = opened()
  d.run(350, 550, null, { faceDetected: false, face: null })
  d.feed(600, OPEN)
  d.run(650, 1200, OPEN)
  assert.equal(d.phase, "open")
})

test("安定待ち中の顔ロストも 300ms までは待ち、300ms を超えたら顔なしになる", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  assert.equal(d.phase, "refractory")
  d.run(1250, 1550, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "refractory")
  d.feed(1600, null, { faceDetected: false, face: null })
  assert.equal(d.phase, "noface")
})

const NO_FACE = { faceDetected: false, face: null }

test("開眼中の顔ロストが 300ms を超えてから顔が戻ったら、準備中からやり直す（そのまま閉じても決定しない）", () => {
  const d = opened()
  d.run(350, 650, null, NO_FACE)
  assert.equal(d.phase, "open", "消えてから 300ms ちょうどはまだ開眼")
  // 最初に顔が消えた 350ms から 350ms たって、閉じた目で戻ってきた
  d.feed(700, CLOSED)
  assert.equal(d.phase, "arming", "猶予が切れているので、開いた目をもう一度確認する")
  d.run(750, 1500, CLOSED)
  d.feed(1550, OPEN)
  assert.equal(d.count("holdReached"), 0)
  assert.equal(d.count("select"), 0)
})

test("開眼中の顔ロストが 300ms ちょうどで戻ったなら開眼のままで、長いまばたきを決定できる", () => {
  const d = opened()
  d.run(350, 600, null, NO_FACE)
  d.feed(650, CLOSED)
  assert.equal(d.phase, "closing")
  d.run(700, 1450, CLOSED)
  d.feed(1500, OPEN)
  assert.equal(d.count("select"), 1)
})

test("安定待ち中の顔ロストが 300ms を超えてから顔が戻ったら、準備中からやり直す", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  assert.equal(d.phase, "refractory")
  d.run(1250, 1550, null, NO_FACE)
  assert.equal(d.phase, "refractory", "消えてから 300ms ちょうどはまだ安定待ち")
  d.feed(1600, OPEN)
  assert.equal(d.phase, "arming")
  // 安定待ちの 800ms（2000ms）を過ぎても、開眼の確認 300ms（1900ms）を通るまでは開眼にしない
  d.run(1650, 1850, OPEN)
  assert.equal(d.phase, "arming")
  d.feed(1900, OPEN)
  assert.equal(d.phase, "open")
})

test("安定待ち中の顔ロストが 300ms ちょうどで戻ったなら安定待ちのまま", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  d.run(1250, 1500, null, NO_FACE)
  d.feed(1550, OPEN)
  assert.equal(d.phase, "refractory")
  d.run(1600, 2000, OPEN)
  assert.equal(d.phase, "open")
})

for (const [label, missing] of [["null", null], ["NaN", NaN], ["undefined", undefined]]) {
  test(`欠けたスコア（${label}）を開眼扱いしない: 決定待ちで届いても決定しない`, () => {
    const d = opened()
    d.run(350, 1150, CLOSED)
    d.feed(1200, missing)
    assert.equal(d.count("select"), 0)
    assert.notEqual(d.phase, "refractory")
    d.run(1250, 1400, OPEN)
    assert.equal(d.count("select"), 0, "取り消されたので、あとで開いても決定しない")
  })

  test(`欠けたスコア（${label}）を開眼扱いしない: 準備中の開眼確認に数えない`, () => {
    const d = driver()
    d.feed(0, OPEN)
    d.run(50, 600, missing)
    assert.notEqual(d.phase, "open")
  })
}

test("両目モードでは片方のスコアが欠けたフレームを使わない", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN, { leftScore: null })
  assert.equal(d.count("select"), 0)
})

test("右目モードは右のスコアだけで判定する（左が欠けていてもよい）", () => {
  const d = driver({ ...SETTINGS, eye: "right" })
  d.run(0, 300, OPEN, { leftScore: null })
  assert.equal(d.phase, "open")
  d.run(350, 1150, OPEN, { rightScore: CLOSED })
  assert.equal(d.phase, "ready")
  d.feed(1200, CLOSED, { rightScore: OPEN })
  assert.equal(d.count("select"), 1)
})

test("左目モードは左のスコアだけで判定する", () => {
  const d = driver({ ...SETTINGS, eye: "left" })
  d.run(0, 300, CLOSED, { leftScore: OPEN })
  assert.equal(d.phase, "open")
  d.run(350, 1150, OPEN, { leftScore: CLOSED })
  assert.equal(d.phase, "ready")
})

test("フレームの間隔が 250ms を超えたら保持を取り消す", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.feed(851, CLOSED)
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "frameGap", key: "A" })
  assert.equal(d.phase, "arming")
  d.run(900, 1700, CLOSED)
  d.run(1750, 1800, OPEN)
  assert.equal(d.count("select"), 0)
})

test("フレームの間隔が 250ms ちょうどなら保持を続ける", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.feed(850, CLOSED)
  d.feed(1100, CLOSED)
  d.feed(1150, CLOSED)
  assert.equal(d.phase, "ready")
})

test("結果が 500ms 来なければ、見張り（tick）で保持を取り消す", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.tick(1099)
  assert.equal(d.phase, "closing", "499ms ではまだ")
  d.tick(1100)
  assert.equal(d.phase, "arming")
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "watchdog", key: "A" })
})

test("決定待ちでも、結果が 500ms 来なければ取り消す", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.tick(1650)
  assert.equal(d.phase, "arming")
  d.feed(1700, OPEN)
  assert.equal(d.count("select"), 0)
})

// 顔の急変: どの状態からでも取り消して準備中へ戻る
// それぞれの状態まで進め、最後に流したフレームの撮影時刻を返す
const reachers = {
  arming: (d) => { d.run(0, 100, OPEN); return 100 },
  open: (d) => { d.run(0, 300, OPEN); return 300 },
  closing: (d) => { d.run(0, 300, OPEN); d.run(350, 600, CLOSED); return 600 },
  ready: (d) => { d.run(0, 300, OPEN); d.run(350, 1150, CLOSED); return 1150 },
  refractory: (d) => { d.run(0, 300, OPEN); d.run(350, 1150, CLOSED); d.feed(1200, OPEN); return 1200 },
  rest: (d) => { d.run(0, 300, OPEN); d.run(350, 5350, CLOSED); return 5350 }
}
const jumps = {
  "位置": { x: 0.9, y: 0.5, size: 0.3 },
  "大きさ": { x: 0.5, y: 0.5, size: 0.45 }
}
for (const [phase, reach] of Object.entries(reachers)) {
  for (const [what, face] of Object.entries(jumps)) {
    test(`顔の${what}が急に変わったら、${phase} から準備中へ戻り決定しない`, () => {
      const d = driver()
      const t = reach(d) + FRAME_MS
      assert.equal(d.phase, phase)
      const selectsBefore = d.count("select")
      d.feed(t, OPEN, { face })
      assert.equal(d.phase, "arming")
      assert.equal(d.count("select"), selectsBefore)
      d.run(t + 50, t + 250, OPEN, { face })
      assert.equal(d.phase, "arming", "開眼は 300ms かけて確認し直す")
      d.feed(t + 300, OPEN, { face })
      assert.equal(d.phase, "open")
    })
  }
}

test("顔の急変で保持が取り消されたことをイベントで知らせる", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.feed(650, CLOSED, { face: jumps["位置"] })
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "faceChanged", key: "A" })
})

test("顔が少し動いただけでは取り消さない", () => {
  const d = opened()
  d.run(350, 600, CLOSED)
  d.run(650, 1150, CLOSED, { face: { x: 0.52, y: 0.51, size: 0.31 } })
  assert.equal(d.phase, "ready")
})

test("撮影時刻が逆戻りしたフレームは捨てる（状態は変わらない）", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  const before = d.state
  const events = d.feed(1000, OPEN)
  assert.deepEqual(events, [{ type: "discard", reason: "outOfOrder" }])
  assert.deepEqual(d.state, before)
})

test("通し番号が戻ったフレームは捨てる", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  const before = d.state
  const events = d.feed(1200, OPEN, { seq: 3 })
  assert.deepEqual(events, [{ type: "discard", reason: "outOfOrder" }])
  assert.deepEqual(d.state, before)
})

test("候補は閉眼を初めて認めたフレームの項目に固定する（切り替わる直前に閉じた場合）", () => {
  const d = opened()
  d.feed(350, CLOSED, { highlightedKey: "A" })
  d.run(400, 1150, CLOSED, { highlightedKey: "B" })
  assert.deepEqual(d.last("holdReached"), { type: "holdReached", key: "A" })
  d.feed(1200, OPEN, { highlightedKey: "B" })
  assert.deepEqual(d.last("select"), { type: "select", key: "A" })
})

for (const latency of [150, 250]) {
  test(`結果が ${latency}ms 遅れて届いても、撮影時に光っていた項目で決定する`, () => {
    const d = driver()
    d.run(0, 300, OPEN, { latency })
    assert.equal(d.phase, "open")
    d.run(350, 1150, CLOSED, { latency, highlightedKey: "A" })
    assert.equal(d.phase, "ready")
    d.feed(1200, OPEN, { latency, highlightedKey: "B" })
    assert.deepEqual(d.last("select"), { type: "select", key: "A" })
  })
}

test("撮影から 300ms ちょうどたった結果は使わない（299ms は使う）", () => {
  const d = opened()
  const before = d.state
  const events = d.feed(350, CLOSED, { latency: 300 })
  assert.deepEqual(events, [{ type: "discard", reason: "stale" }])
  assert.deepEqual(d.state, before)
  d.feed(400, CLOSED, { latency: 299 })
  assert.equal(d.phase, "closing")
})

test("世代番号が今と違う結果は捨てる", () => {
  const d = opened()
  const before = d.state
  const events = d.feed(350, CLOSED, { generation: 1 })
  assert.deepEqual(events, [{ type: "discard", reason: "generation" }])
  assert.deepEqual(d.state, before)
})

test("確認に移る前に撮った結果が後から届いても、確認画面の判定に使わない", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  d.feed(1200, OPEN)
  assert.equal(d.count("select"), 1)
  // ここで画面が確認に移り、世代が 0 → 1 になった
  d.run(1250, 2050, OPEN, { generation: 1, currentGeneration: 1, highlightedKey: "no" })
  assert.equal(d.phase, "open")
  const events = d.feed(2100, CLOSED, { generation: 0, currentGeneration: 1, highlightedKey: "A" })
  assert.deepEqual(events, [{ type: "discard", reason: "generation" }])
  assert.equal(d.phase, "open")
})

test("保持の途中で画面の世代が変わったら、古い画面の候補は取り消す", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  assert.equal(d.phase, "ready")
  d.feed(1200, OPEN, { generation: 1, currentGeneration: 1, highlightedKey: "no" })
  assert.equal(d.count("select"), 0)
  assert.deepEqual(d.last("cancel"), { type: "cancel", reason: "generationChanged", key: "A" })
  assert.equal(d.phase, "arming")
})

test("世代が変わった直後に届いたのが古い世代の結果でも、古い画面の候補は取り消す", () => {
  const d = opened()
  d.run(350, 1150, CLOSED)
  const events = d.feed(1200, OPEN, { generation: 0, currentGeneration: 1 })
  assert.deepEqual(events, [
    { type: "cancel", reason: "generationChanged", key: "A" },
    { type: "discard", reason: "generation" }
  ])
  assert.equal(d.phase, "arming")
  d.feed(1250, OPEN, { generation: 1, currentGeneration: 1 })
  assert.equal(d.count("select"), 0)
})

test("何も光っていない時（項目 null）の長いまばたきも、key が null の決定として出す", () => {
  const d = driver()
  d.run(0, 300, OPEN, { highlightedKey: null })
  d.run(350, 1150, CLOSED, { highlightedKey: null })
  d.feed(1200, OPEN, { highlightedKey: null })
  assert.deepEqual(d.last("select"), { type: "select", key: null })
})

test("入力の状態オブジェクトを書き換えない", () => {
  const state = createBlinkSwitch()
  const frozen = Object.freeze({ ...state })
  const input = {
    type: "frame",
    now: 0,
    currentGeneration: 0,
    frame: { capturedAt: 0, seq: 0, generation: 0, highlightedKey: "A", faceDetected: true, leftScore: OPEN, rightScore: OPEN, face: FACE }
  }
  const result = stepBlinkSwitch(frozen, input, SETTINGS)
  assert.equal(frozen.phase, "noface")
  assert.equal(result.state.phase, "arming")
})
