import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULTS, FIXED, RANGES } from "../../app/javascript/blink/config.js"

test("初期値は設計書の表どおり", () => {
  assert.deepEqual(
    {
      eye: DEFAULTS.eye,
      holdMs: DEFAULTS.holdMs,
      armingMs: DEFAULTS.armingMs,
      refractoryMs: DEFAULTS.refractoryMs,
      restMs: DEFAULTS.restMs,
      faceLostGraceMs: DEFAULTS.faceLostGraceMs,
      stepMs: DEFAULTS.stepMs,
      firstStepRatio: DEFAULTS.firstStepRatio,
      autoPauseRounds: DEFAULTS.autoPauseRounds,
      confirmRounds: DEFAULTS.confirmRounds,
      calibrationStaleHours: DEFAULTS.calibrationStaleHours
    },
    {
      eye: "both",
      holdMs: 800,
      armingMs: 300,
      refractoryMs: 800,
      restMs: 5000,
      faceLostGraceMs: 300,
      stepMs: 2000,
      firstStepRatio: 1.5,
      autoPauseRounds: 3,
      confirmRounds: 2,
      calibrationStaleHours: 12
    }
  )
})

test("固定の値（フレーム間隔の上限 250ms・結果の古さ 300ms・見張り 500ms）", () => {
  assert.equal(FIXED.maxFrameGapMs, 250)
  assert.equal(FIXED.maxResultAgeMs, 300)
  assert.equal(FIXED.watchdogMs, 500)
})

test("しきい値の初期値は持たない（調整して初めて決まる）", () => {
  assert.equal("closeThreshold" in DEFAULTS, false)
  assert.equal("openThreshold" in DEFAULTS, false)
})

test("初期値はどれも自分の調整範囲に入っている", () => {
  for (const [field, range] of Object.entries(RANGES)) {
    if (!(field in DEFAULTS)) continue
    assert.ok(DEFAULTS[field] >= range.min && DEFAULTS[field] <= range.max, field)
  }
})

test("初期値と固定の値は書き換えられない", () => {
  assert.throws(() => { DEFAULTS.holdMs = 1 }, TypeError)
  assert.throws(() => { FIXED.watchdogMs = 1 }, TypeError)
})

test("完了表示は 4000ms（調整範囲 2000〜10000ms）。記録の送信は 10 秒で時間切れ", () => {
  assert.equal(DEFAULTS.doneMs, 4000)
  assert.deepEqual({ ...RANGES.doneMs }, { min: 2000, max: 10000 })
  assert.equal(FIXED.sendTimeoutMs, 10000)
})
