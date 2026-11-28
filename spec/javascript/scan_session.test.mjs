// スキャン画面の状態（scan_session）を、キー入力源（key_switch）とつないで確かめる。
// 画面側（scan_controller）と同じつなぎ方: 入力源の結果 { now, phase, events } を type: "switch" で渡す。
import { test } from "node:test"
import assert from "node:assert/strict"
import { createKeySource } from "../../app/javascript/blink/key_switch.js"
import { CONFIRM_NO, CONFIRM_YES } from "../../app/javascript/blink/scan_sequencer.js"
import {
  createScanSession,
  scanView,
  sendOutcome,
  stepScanSession,
  timingSettings
} from "../../app/javascript/blink/scan_session.js"

const ITEMS = [{ key: "a" }, { key: "b" }, { key: "c" }, { key: "pause", kind: "pause" }]
const TICK_MS = 50
const SAVED = { kind: "saved", name: "おちゃ", savedToHistory: true }

function driver({ items = ITEMS, overrides = {} } = {}) {
  const settings = timingSettings(overrides)
  let ids = 0
  const created = createScanSession({ items, settings, newSubmissionId: () => `id-${++ids}` })
  assert.equal(created.ok, true)
  let state = created.state
  const source = createKeySource(settings)
  const effects = []
  const apply = (input) => {
    const result = stepScanSession(state, input)
    state = result.state
    effects.push(...result.effects)
    if (result.effects.some((effect) => effect.type === "resetInput")) source.reset()
    return result.effects
  }
  const d = {
    effects,
    get view() { return scanView(state) },
    get screen() { return d.view.screen },
    get highlighted() { return d.view.highlightedKey },
    get sends() { return effects.filter((effect) => effect.type === "send") },
    start() { return apply({ type: "start" }) },
    stop() { return apply({ type: "stop" }) },
    suspend() { return apply({ type: "suspend" }) },
    resume() { return apply({ type: "resume" }) },
    retry() { return apply({ type: "retry" }) },
    press(now) { return apply({ type: "switch", ...source.press(now, d.highlighted) }) },
    tick(now) { return apply({ type: "switch", ...source.tick(now) }) },
    run(from, to) {
      for (let t = from; t <= to; t += TICK_MS) d.tick(t)
    },
    // 条件が成り立つまで 50ms ごとに進める。成り立った時刻を返す
    runUntil(from, condition) {
      for (let t = from; t <= from + 120000; t += TICK_MS) {
        d.tick(t)
        if (condition()) return t
      }
      throw new Error("条件が成り立たないまま 120 秒たった")
    },
    // いちばん新しい送信への返事（attempt を渡せば、その回の送信への返事）
    result(now, outcome, attempt = d.sends.at(-1).attempt) {
      return apply({ type: "sendResult", now, attempt, outcome })
    }
  }
  return d
}

// 開始して「b」を選び、確認の「はい」が光っている所まで進める。その時刻を返す
function atYes(d, from = 0) {
  d.start()
  const bAt = d.runUntil(from, () => d.highlighted === "b")
  d.press(bAt + 100)
  assert.equal(d.screen, "confirming")
  return d.runUntil(bAt + 150, () => d.highlighted === CONFIRM_YES)
}

// 「b」に「はい」を押して、送信中になった所まで進める。「はい」を押した時刻を返す
function sending(d, from = 0) {
  const yesAt = atYes(d, from) + 100
  d.press(yesAt)
  assert.equal(d.screen, "sending")
  return yesAt
}

test("設定: 何も渡さなければ初期値。まばたきのしきい値・使う目は入れない（キー入力では使わない）", () => {
  assert.deepEqual(timingSettings(), {
    stepMs: 2000,
    firstStepRatio: 1.5,
    autoPauseRounds: 3,
    confirmRounds: 2,
    refractoryMs: 800,
    doneMs: 4000
  })
})

test("設定: 上書き（data 属性から来る値）は、正の数だけ使う。おかしな値と知らない名前は捨てて初期値のまま", () => {
  assert.deepEqual(
    timingSettings({ stepMs: 300, refractoryMs: 100, doneMs: 500, autoPauseRounds: 2, confirmRounds: 1, firstStepRatio: 1 }),
    { stepMs: 300, firstStepRatio: 1, autoPauseRounds: 2, confirmRounds: 1, refractoryMs: 100, doneMs: 500 }
  )
  assert.deepEqual(
    timingSettings({ stepMs: -1, refractoryMs: "100", doneMs: NaN, autoPauseRounds: 1.5, confirmRounds: 0, closeThreshold: 0.6, eye: "left" }),
    timingSettings()
  )
  assert.deepEqual(timingSettings(null), timingSettings())
  assert.deepEqual(timingSettings("x"), timingSettings())
})

test("設定: 先頭の項目の時間は 1 項目の時間より短くしない（firstStepRatio が 1 未満の上書きは捨てる）", () => {
  assert.equal(timingSettings({ firstStepRatio: 0.5 }).firstStepRatio, 1.5)
})

test("項目が空・key が重なっている時は、画面の状態を作らない", () => {
  const settings = timingSettings()
  assert.deepEqual(createScanSession({ items: [], settings, newSubmissionId: () => "x" }), { ok: false, error: "emptyItems" })
  assert.deepEqual(
    createScanSession({ items: [{ key: "a" }, { key: "a" }], settings, newSubmissionId: () => "x" }),
    { ok: false, error: "invalidItems" }
  )
})

test("開始を押すまでは止まっている。何も光らず、押しても何も起きない", () => {
  const d = driver()
  assert.equal(d.screen, "idle")
  assert.equal(d.highlighted, null)
  d.press(100)
  d.run(150, 5000)
  assert.equal(d.screen, "idle")
  assert.deepEqual(d.effects, [])
})

test("開始すると先頭から光る。先頭は 3000ms、そのあとは 2000ms ごとに次へ移る", () => {
  const d = driver()
  d.start()
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  d.run(0, 2950)
  assert.equal(d.highlighted, "a")
  d.tick(3000)
  assert.equal(d.highlighted, "b")
  d.run(3050, 4950)
  assert.equal(d.highlighted, "b")
  d.tick(5000)
  assert.equal(d.highlighted, "c")
})

test("光っている項目で押すと確認に入る。安定待ち（800ms）のあと「いいえ」から光り、次に「はい」が光る", () => {
  const d = driver()
  d.start()
  d.run(0, 3000)
  d.press(3100)
  assert.equal(d.screen, "confirming")
  assert.equal(d.view.pendingKey, "b")
  assert.equal(d.highlighted, null)
  d.run(3150, 3850)
  assert.equal(d.highlighted, null, "安定待ちのあいだは、まだ何も光らせない")
  d.tick(3900)
  assert.equal(d.highlighted, CONFIRM_NO)
  d.run(3950, 5850)
  assert.equal(d.highlighted, CONFIRM_NO)
  d.tick(5900)
  assert.equal(d.highlighted, CONFIRM_YES)
  assert.deepEqual(d.sends, [])
})

test("確認に入った直後（安定待ちのあいだ）に押しても、何も選ばれない", () => {
  const d = driver()
  d.start()
  d.run(0, 3000)
  d.press(3100)
  d.press(3200)
  d.press(3800)
  assert.equal(d.screen, "confirming")
  assert.deepEqual(d.sends, [])
})

test("「はい」で押すと送信中になり、選んだ定型文の key と新しい送信IDで、送信が 1 回だけ出る", () => {
  const d = driver()
  sending(d)
  assert.deepEqual(d.sends, [{ type: "send", attempt: 1, flowItemKey: "b", submissionId: "id-1" }])
  assert.equal(d.view.pendingKey, "b")
  assert.equal(d.highlighted, null)
})

test("「いいえ」で押すとスキャンの先頭に戻り、送信は出ない", () => {
  const d = driver()
  d.start()
  d.run(0, 3000)
  d.press(3100)
  const noAt = d.runUntil(3150, () => d.highlighted === CONFIRM_NO)
  d.press(noAt + 100)
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.deepEqual(d.sends, [])
})

test("確認で何も押さないまま「いいえ→はい」を 2 周すると、スキャンの先頭に戻り、送信は出ない", () => {
  const d = driver()
  d.start()
  d.run(0, 3000)
  d.press(3100)
  // 3900ms に「いいえ」が光り、2000ms × 4 = 8000ms 後の 11900ms で戻る
  d.run(3150, 11850)
  assert.equal(d.screen, "confirming")
  d.tick(11900)
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.deepEqual(d.sends, [])
})

test("送信中に押しても、もう 1 回は送らない", () => {
  const d = driver()
  const yesAt = sending(d)
  d.run(yesAt + 50, yesAt + 3000)
  d.press(yesAt + 3050)
  assert.equal(d.screen, "sending")
  assert.equal(d.sends.length, 1)
})

test("記録できたら完了表示（名前・履歴に残ったか）を出し、4000ms たつとスキャンの先頭に戻る", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 200, SAVED)
  assert.equal(d.screen, "done")
  assert.deepEqual(d.view.done, { name: "おちゃ", savedToHistory: true })
  assert.equal(d.highlighted, null)
  d.run(yesAt + 250, yesAt + 4150)
  assert.equal(d.screen, "done", "3950ms ではまだ完了表示")
  d.tick(yesAt + 4200)
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.view.done, null)
})

test("完了表示のあいだに押しても、何も選ばれない", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 200, SAVED)
  d.press(yesAt + 2000)
  assert.equal(d.screen, "done")
  assert.equal(d.sends.length, 1)
})

test("ゲストの記録（履歴に残らない）も完了表示になり、「履歴に残らない」と分かる", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 200, { kind: "saved", name: "おちゃ", savedToHistory: false })
  assert.deepEqual(d.view.done, { name: "おちゃ", savedToHistory: false })
})

test("完了のあと、次に選んだ時は新しい送信IDを作る", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 200, SAVED)
  const backAt = d.runUntil(yesAt + 250, () => d.screen === "scanning")
  d.press(backAt + 100)
  const secondYes = d.runUntil(backAt + 150, () => d.highlighted === CONFIRM_YES)
  d.press(secondYes + 100)
  assert.deepEqual(d.sends.at(-1), { type: "send", attempt: 2, flowItemKey: "a", submissionId: "id-2" })
})

test("届いたか分からない時は「確認できません」になり、「もう一度送る」は同じ送信IDで送り直す", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  assert.equal(d.screen, "unknown")
  assert.equal(d.view.pendingKey, "b")
  assert.equal(d.view.failures, 1)
  d.retry()
  assert.equal(d.screen, "sending")
  assert.deepEqual(d.sends.at(-1), { type: "send", attempt: 2, flowItemKey: "b", submissionId: "id-1" })
  d.result(yesAt + 20000, { kind: "unknown" })
  assert.equal(d.view.failures, 2)
  d.retry()
  assert.equal(d.sends.at(-1).submissionId, "id-1")
  d.result(yesAt + 21000, SAVED)
  assert.equal(d.screen, "done")
  assert.equal(d.view.failures, 0)
})

test("「確認できません」のあいだに押しても、スキャン入力としては何も起きない（送り直すのは介助者のボタンだけ）", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  d.press(yesAt + 11000)
  d.run(yesAt + 11050, yesAt + 20000)
  assert.equal(d.screen, "unknown")
  assert.equal(d.sends.length, 1)
})

test("送り直したあとに、前の回の返事が遅れて届いても使わない", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  d.retry()
  d.result(yesAt + 10500, { kind: "halt", reason: "notFound" }, 1)
  assert.equal(d.screen, "sending")
  d.result(yesAt + 11000, SAVED, 2)
  assert.equal(d.screen, "done")
})

test("404・409・422 などは介助者を呼ぶ表示で止まり、そのあとは押しても・開始しても・送り直しても動かない", () => {
  for (const reason of ["notFound", "conflict", "reload", "unauthorized", "forbidden", "rateLimited"]) {
    const d = driver()
    const yesAt = sending(d)
    d.result(yesAt + 200, { kind: "halt", reason })
    assert.equal(d.screen, "halted")
    assert.equal(d.view.haltReason, reason)
    d.press(yesAt + 2000)
    d.start()
    d.retry()
    d.suspend()
    d.resume()
    d.run(yesAt + 2050, yesAt + 10000)
    assert.equal(d.screen, "halted")
    assert.equal(d.sends.length, 1)
  }
})

test("停止すると止まり、次に開始した時は先頭からやり直す（確認の途中だった候補は持ち越さない）", () => {
  const d = driver()
  const yesAt = atYes(d)
  d.stop()
  assert.equal(d.screen, "idle")
  assert.equal(d.highlighted, null)
  d.press(yesAt + 100)
  assert.deepEqual(d.sends, [])
  d.start()
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.view.pendingKey, null)
})

test("送信中に停止したら、あとから届いた返事で画面を進めない", () => {
  const d = driver()
  const yesAt = sending(d)
  const effects = d.stop()
  assert.ok(effects.some((effect) => effect.type === "cancelSend"))
  d.result(yesAt + 500, SAVED)
  assert.equal(d.screen, "idle")
  assert.equal(d.view.done, null)
})

// 保存はできたのに返事が届く前に介助者が「停止」を押した、という並び。
// 止めても「届いたか分からない送信」は残す（捨てると、次の「はい」が新しい送信ID になり二重に記録される）
test("送信中に停止 → 開始すると、スキャンには戻らず「確認できません」に戻る。送り直しは同じ送信ID", () => {
  const d = driver()
  const yesAt = sending(d)
  d.stop()
  d.result(yesAt + 500, SAVED)
  assert.equal(d.screen, "idle")
  d.press(yesAt + 600)
  d.run(yesAt + 650, yesAt + 5000)
  assert.equal(d.sends.length, 1, "止まっているあいだは送らない")

  d.start()
  assert.equal(d.screen, "unknown")
  assert.equal(d.highlighted, null)
  assert.equal(d.view.pendingKey, "b")
  d.press(yesAt + 6000)
  assert.equal(d.sends.length, 1, "スキャン入力では送り直さない")

  d.retry()
  assert.equal(d.screen, "sending")
  assert.equal(d.sends.length, 2)
  assert.equal(d.sends[1].flowItemKey, "b")
  assert.equal(d.sends[1].submissionId, d.sends[0].submissionId)
  assert.notEqual(d.sends[1].attempt, d.sends[0].attempt)
})

test("「確認できません」で停止 → 開始しても「確認できません」のまま。送り直しは同じ送信IDで、記録できたら次は新しい送信ID", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  d.stop()
  assert.equal(d.screen, "idle")
  d.start()
  assert.equal(d.screen, "unknown")
  assert.equal(d.view.pendingKey, "b")

  d.retry()
  assert.equal(d.sends[1].submissionId, "id-1")
  d.result(yesAt + 11000, SAVED)
  assert.equal(d.screen, "done")

  const againAt = sending(d, d.runUntil(yesAt + 11050, () => d.screen === "scanning"))
  assert.ok(againAt > yesAt)
  assert.equal(d.sends.length, 3)
  assert.equal(d.sends[2].submissionId, "id-2")
})

test("送信の失敗が続いたことは、停止 → 開始をはさんでも数え続ける（「何度も続く場合は」を出すため）", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  assert.equal(d.view.failures, 1)
  d.retry()
  d.stop()
  d.start()
  assert.equal(d.screen, "unknown")
  assert.equal(d.view.failures, 2, "打ち切った送り直しも、届いたか分からない 1 回")
  d.stop()
  d.start()
  assert.equal(d.view.failures, 2, "止めて始めただけでは増えない")
})

test("届いたか分からない送信を残して止めているあいだは、画面が隠れて戻っても自動では再開しない", () => {
  const d = driver()
  sending(d)
  d.stop()
  d.suspend()
  d.resume()
  assert.equal(d.screen, "idle")
  d.start()
  assert.equal(d.screen, "unknown")
})

test("「はい」が光っている時に画面が隠れ、戻ってきたら先頭からやり直す（戻ってすぐ押しても送信にならない）", () => {
  const d = driver()
  const yesAt = atYes(d)
  d.suspend()
  assert.equal(d.highlighted, null)
  d.press(yesAt + 100)
  assert.deepEqual(d.sends, [], "隠れているあいだの入力は使わない")
  d.resume()
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  d.press(yesAt + 5000)
  assert.equal(d.screen, "confirming")
  assert.equal(d.view.pendingKey, "a")
  assert.deepEqual(d.sends, [])
})

test("画面が隠れる直前に押して安定待ちだった入力源も、戻ったら受付中からやり直す", () => {
  const d = driver()
  d.start()
  d.run(0, 3000)
  d.press(3100)
  d.suspend()
  d.resume()
  d.press(3200)
  assert.equal(d.screen, "confirming")
  assert.equal(d.view.pendingKey, "a")
})

test("介助者が止めていた時は、画面が隠れて戻っても、自動では再開しない", () => {
  const d = driver()
  d.start()
  d.stop()
  d.suspend()
  d.resume()
  assert.equal(d.screen, "idle")
  const e = driver()
  e.suspend()
  e.resume()
  assert.equal(e.screen, "idle")
})

test("送信中に画面が隠れたら、送信を打ち切って「確認できません」にする。遅れて届いた返事は使わず、送り直しは同じ送信ID", () => {
  const d = driver()
  const yesAt = sending(d)
  const effects = d.suspend()
  assert.ok(effects.some((effect) => effect.type === "cancelSend"))
  d.result(yesAt + 300, SAVED)
  d.resume()
  assert.equal(d.screen, "unknown")
  assert.equal(d.view.pendingKey, "b")
  d.retry()
  assert.deepEqual(d.sends.at(-1), { type: "send", attempt: 3, flowItemKey: "b", submissionId: "id-1" })
})

test("完了表示のあいだに画面が隠れて戻ったら、スキャンの先頭からやり直す", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 200, SAVED)
  d.suspend()
  d.resume()
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.equal(d.view.done, null)
})

test("「確認できません」のあいだに画面が隠れて戻っても、そのまま（送り直しを待つ）", () => {
  const d = driver()
  const yesAt = sending(d)
  d.result(yesAt + 10000, { kind: "unknown" })
  d.suspend()
  d.resume()
  assert.equal(d.screen, "unknown")
  assert.equal(d.view.pendingKey, "b")
})

test("「休止」を選ぶと休止になり、もう一度押すと先頭から再開する", () => {
  const d = driver()
  d.start()
  const pauseAt = d.runUntil(0, () => d.highlighted === "pause")
  d.press(pauseAt + 100)
  assert.equal(d.screen, "paused")
  assert.equal(d.highlighted, null)
  d.run(pauseAt + 150, pauseAt + 20000)
  assert.equal(d.screen, "paused")
  d.press(pauseAt + 20050)
  assert.equal(d.screen, "scanning")
  assert.equal(d.highlighted, "a")
  assert.deepEqual(d.sends, [])
})

test("だれも選ばないまま 3 周すると、自動で休止になる", () => {
  const d = driver()
  d.start()
  // 1 周 = 3000 + 2000 × 3 = 9000ms。3 周で 27000ms
  d.run(0, 26950)
  assert.equal(d.screen, "scanning")
  d.tick(27000)
  assert.equal(d.screen, "paused")
})

test("時間の上書き（system spec 用の短い設定）でも、同じ流れで動く", () => {
  const d = driver({ overrides: { stepMs: 300, refractoryMs: 100, doneMs: 500 } })
  d.start()
  d.run(0, 400)
  assert.equal(d.highlighted, "a")
  d.tick(450)
  assert.equal(d.highlighted, "b")
  d.press(500)
  d.run(550, 600)
  assert.equal(d.highlighted, CONFIRM_NO)
  d.run(650, 900)
  assert.equal(d.highlighted, CONFIRM_YES)
  d.press(950)
  d.result(1000, SAVED)
  d.run(1050, 1450)
  assert.equal(d.screen, "done")
  d.tick(1500)
  assert.equal(d.screen, "scanning")
})

test("返事の読み方: 201 / 200 で名前があれば「記録できた」。履歴に残ったかは saved_to_history が true の時だけ", () => {
  assert.deepEqual(sendOutcome({ status: 201, body: { name: "おちゃ", saved_to_history: true } }), { kind: "saved", name: "おちゃ", savedToHistory: true })
  assert.deepEqual(
    sendOutcome({ status: 200, body: { name: "おちゃ", saved_to_history: true, already_saved: true } }),
    { kind: "saved", name: "おちゃ", savedToHistory: true }
  )
  assert.deepEqual(sendOutcome({ status: 201, body: { name: "おちゃ", saved_to_history: false } }), { kind: "saved", name: "おちゃ", savedToHistory: false })
  assert.deepEqual(sendOutcome({ status: 201, body: { name: "おちゃ" } }), { kind: "saved", name: "おちゃ", savedToHistory: false })
})

test("返事の読み方: 201 / 200 でも中身が読めない（壊れた JSON・HTML が返った・名前が無い）なら「届いたか不明」", () => {
  for (const body of [undefined, null, "<html>", [], {}, { name: "" }, { name: 5 }]) {
    assert.deepEqual(sendOutcome({ status: 200, body }), { kind: "unknown" })
    assert.deepEqual(sendOutcome({ status: 201, body }), { kind: "unknown" })
  }
})

test("返事の読み方: 404・409・422・401・403・429 は、それぞれの理由で止める", () => {
  const reasons = { 404: "notFound", 409: "conflict", 422: "reload", 401: "unauthorized", 403: "forbidden", 429: "rateLimited" }
  for (const [status, reason] of Object.entries(reasons)) {
    assert.deepEqual(sendOutcome({ status: Number(status), body: { error: "x" } }), { kind: "halt", reason })
  }
})

test("返事の読み方: 5xx・そのほかの状態コード・返事なし（通信エラー・時間切れ）は「届いたか不明」", () => {
  for (const status of [500, 502, 503, 504, 400, 406, 302, 204, 0]) {
    assert.deepEqual(sendOutcome({ status, body: { name: "おちゃ" } }), { kind: "unknown" })
  }
  assert.deepEqual(sendOutcome(null), { kind: "unknown" })
  assert.deepEqual(sendOutcome(undefined), { kind: "unknown" })
})
