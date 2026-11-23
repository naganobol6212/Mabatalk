import { test } from "node:test"
import assert from "node:assert/strict"
import { DEFAULTS } from "../../app/javascript/blink/config.js"
import {
  calibrate,
  checkSavedCalibration,
  computeThresholds,
  settingsFromCalibration,
  toSavedCalibration,
  validateSettings
} from "../../app/javascript/blink/calibration.js"

const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-9, `${actual} ≒ ${expected}`)
const frames = (count, leftScore, rightScore = leftScore) =>
  Array.from({ length: count }, () => ({ leftScore, rightScore }))
const HOUR_MS = 60 * 60 * 1000
const VALID = { ...DEFAULTS, closeThreshold: 0.6, openThreshold: 0.25 }

// ---- しきい値の計算 ----

test("閉じしきい値は O + 0.6×(C−O)、開きしきい値は O + 0.25×(C−O)", () => {
  const result = computeThresholds(0.1, 0.9)
  assert.equal(result.ok, true)
  near(result.closeThreshold, 0.58)
  near(result.openThreshold, 0.3)
})

test("C−O が 0.29 ちょうどならしきい値を作れる（差がほぼ 0.1）", () => {
  const result = computeThresholds(0.2, 0.49)
  assert.equal(result.ok, true)
  near(result.closeThreshold, 0.374)
  near(result.openThreshold, 0.2725)
})

test("C−O が 0.29 未満ならしきい値を作らない", () => {
  assert.deepEqual(computeThresholds(0.2, 0.48), { ok: false, reason: "lowContrast" })
  assert.deepEqual(computeThresholds(0.6, 0.2), { ok: false, reason: "lowContrast" })
})

test("O や C が数値でなければしきい値を作らない", () => {
  for (const bad of [NaN, null, undefined, "0.5", Infinity]) {
    assert.deepEqual(computeThresholds(bad, 0.9), { ok: false, reason: "notNumeric" })
    assert.deepEqual(computeThresholds(0.1, bad), { ok: false, reason: "notNumeric" })
  }
})

test("計算した閉じしきい値が調整範囲（0.2〜0.9）を外れるなら作らない", () => {
  // O=0, C=0.3 → 閉じしきい値 0.18
  assert.deepEqual(computeThresholds(0, 0.3), { ok: false, reason: "thresholdOutOfRange" })
})

// ---- 調整 ----

test("開いた目・閉じた目それぞれの中央値を O と C にして、しきい値を返す", () => {
  const openFrames = [...frames(40, 0.1), ...frames(5, 0.8)]
  const closedFrames = [...frames(40, 0.9), ...frames(5, 0.85)]
  const result = calibrate({ openFrames, closedFrames, eye: "both" })
  assert.equal(result.ok, true)
  near(result.calibration.open, 0.1)
  near(result.calibration.closed, 0.9)
  near(result.calibration.closeThreshold, 0.58)
  near(result.calibration.openThreshold, 0.3)
  assert.equal(result.calibration.eye, "both")
})

test("両目モードの1フレームのスコアは左右の平均", () => {
  const result = calibrate({ openFrames: frames(40, 0.0, 0.2), closedFrames: frames(40, 0.8, 1.0), eye: "both" })
  near(result.calibration.open, 0.1)
  near(result.calibration.closed, 0.9)
})

test("片目モードはその目のスコアだけを使う", () => {
  const result = calibrate({ openFrames: frames(40, 0.5, 0.1), closedFrames: frames(40, 0.5, 0.9), eye: "right" })
  assert.equal(result.ok, true)
  near(result.calibration.open, 0.1)
  near(result.calibration.closed, 0.9)
  assert.equal(result.calibration.eye, "right")
})

test("有効なフレームが足りなければ失敗する", () => {
  const result = calibrate({ openFrames: frames(29, 0.1), closedFrames: frames(40, 0.9), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "insufficientFrames")
})

test("数値でないスコアのフレームは有効フレームに数えない", () => {
  const openFrames = [...frames(29, 0.1), ...frames(20, null), ...frames(20, NaN), ...frames(20, undefined), ...frames(20, "0.1")]
  const result = calibrate({ openFrames, closedFrames: frames(40, 0.9), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "insufficientFrames")
})

test("フレームの並びが配列でなければ失敗する", () => {
  const result = calibrate({ openFrames: null, closedFrames: frames(40, 0.9), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "insufficientFrames")
})

test("開いた時と閉じた時のばらつきが重なりすぎると失敗する", () => {
  // 中央値は 0.1 と 0.9 で離れているが、開いた時の 3 割が 0.95、閉じた時の 3 割が 0.05
  const openFrames = [...frames(28, 0.1), ...frames(12, 0.95)]
  const closedFrames = [...frames(28, 0.9), ...frames(12, 0.05)]
  const result = calibrate({ openFrames, closedFrames, eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "overlap")
})

test("両目では差が足りず右目なら足りる時は、右目をすすめる", () => {
  // 左はまったく動かない（0.1→0.1）、右はよく動く（0.1→0.6）。両目の平均は 0.1→0.35 で差 0.25
  const result = calibrate({ openFrames: frames(40, 0.1, 0.1), closedFrames: frames(40, 0.1, 0.6), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "lowContrast")
  assert.equal(result.suggestedEye, "right")
})

test("両目では差が足りず左目なら足りる時は、左目をすすめる", () => {
  const result = calibrate({ openFrames: frames(40, 0.1, 0.1), closedFrames: frames(40, 0.6, 0.1), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.suggestedEye, "left")
})

test("右目モードで差が足りず左目なら足りる時は、左目をすすめる", () => {
  const result = calibrate({ openFrames: frames(40, 0.1, 0.1), closedFrames: frames(40, 0.6, 0.1), eye: "right" })
  assert.equal(result.ok, false)
  assert.equal(result.suggestedEye, "left")
})

test("左右とも片目なら使える時は、開閉の差が大きい方の目をすすめる", () => {
  // 片目ずつ見るとどちらも分かれている（左 0.1→0.9、右 0.1→0.7）が、
  // 左右が別々のフレームで外れるため、両目の平均だけ開閉のばらつきが重なる
  const openFrames = [...frames(34, 0.1, 0.1), ...frames(3, 1.0, 0.1), ...frames(3, 0.1, 1.0)]
  const closedFrames = [...frames(34, 0.9, 0.7), ...frames(3, 0.0, 0.7), ...frames(3, 0.9, 0.0)]
  const result = calibrate({ openFrames, closedFrames, eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "overlap")
  assert.equal(result.suggestedEye, "left")
})

test("左右どちらも差が足りない時は、目をすすめない（タップ/介助者操作へ）", () => {
  const result = calibrate({ openFrames: frames(40, 0.1), closedFrames: frames(40, 0.3), eye: "both" })
  assert.equal(result.ok, false)
  assert.equal(result.reason, "lowContrast")
  assert.equal(result.suggestedEye, null)
})

// ---- 値どうしの決まり ----

test("初期値に調整したしきい値を足した設定は通る", () => {
  assert.deepEqual(validateSettings(VALID), { ok: true, errors: [] })
})

test("しきい値が無い（調整していない）設定は拒否する", () => {
  const result = validateSettings(DEFAULTS)
  assert.equal(result.ok, false)
  assert.ok(result.errors.includes("notCalibrated"))
})

test("開きしきい値が閉じしきい値より 0.1 以上低くなければ拒否する", () => {
  const bad = validateSettings({ ...VALID, closeThreshold: 0.6, openThreshold: 0.51 })
  assert.equal(bad.ok, false)
  assert.ok(bad.errors.includes("thresholdGapTooSmall"))
  assert.equal(validateSettings({ ...VALID, closeThreshold: 0.6, openThreshold: 0.5 }).ok, true)
})

test("保持時間 + 1000ms が休憩の長さを超える組み合わせは拒否する", () => {
  const bad = validateSettings({ ...VALID, holdMs: 2100, restMs: 3000 })
  assert.equal(bad.ok, false)
  assert.ok(bad.errors.includes("holdTooCloseToRest"))
  assert.equal(validateSettings({ ...VALID, holdMs: 2000, restMs: 3000 }).ok, true)
})

test("先頭の時間が1項目の時間より短くなる倍率は拒否する", () => {
  const bad = validateSettings({ ...VALID, firstStepRatio: 0.9 })
  assert.equal(bad.ok, false)
  assert.ok(bad.errors.includes("firstStepShorterThanStep"))
  assert.equal(validateSettings({ ...VALID, firstStepRatio: 1 }).ok, true)
})

for (const [field, low, high] of [
  ["holdMs", 300, 3100],
  ["closeThreshold", 0.19, 0.91],
  ["armingMs", 199, 1001],
  ["refractoryMs", 299, 2001],
  ["restMs", 2999, 15001],
  ["faceLostGraceMs", 99, 1001],
  ["stepMs", 799, 5001],
  ["autoPauseRounds", 0, 11],
  ["confirmRounds", 0, 6],
  ["calibrationStaleHours", 0, 49]
]) {
  test(`${field} が調整範囲の外なら拒否する`, () => {
    for (const value of [low, high]) {
      const result = validateSettings({ ...VALID, openThreshold: 0.05, [field]: value })
      assert.equal(result.ok, false, `${field}=${value}`)
      assert.ok(result.errors.includes(`${field}OutOfRange`), `${field}=${value}: ${result.errors}`)
    }
  })
}

test("先頭の倍率が 2 倍を超えたら拒否する", () => {
  assert.ok(validateSettings({ ...VALID, firstStepRatio: 2.1 }).errors.includes("firstStepRatioOutOfRange"))
})

test("保持時間が 100ms 刻みでなければ拒否する", () => {
  assert.ok(validateSettings({ ...VALID, holdMs: 850 }).errors.includes("holdMsOutOfRange"))
})

test("周の回数が整数でなければ拒否する", () => {
  assert.ok(validateSettings({ ...VALID, autoPauseRounds: 2.5 }).errors.includes("autoPauseRoundsOutOfRange"))
})

test("使う目が 両目/右/左 以外なら拒否する", () => {
  assert.ok(validateSettings({ ...VALID, eye: "middle" }).errors.includes("eyeInvalid"))
  for (const eye of ["both", "right", "left"]) assert.equal(validateSettings({ ...VALID, eye }).ok, true)
})

test("数値でない値は拒否する", () => {
  assert.equal(validateSettings({ ...VALID, stepMs: "2000" }).ok, false)
  assert.equal(validateSettings({ ...VALID, holdMs: NaN }).ok, false)
})

// ---- 調整結果から設定を作る ----

test("調整していなければ設定を作らない（決まった値で黙って始めない）", () => {
  assert.deepEqual(settingsFromCalibration(null), { ok: false, errors: ["notCalibrated"] })
  assert.deepEqual(settingsFromCalibration(undefined), { ok: false, errors: ["notCalibrated"] })
})

test("調整結果から、初期値にしきい値と使う目を足した設定を作る", () => {
  const calibration = calibrate({ openFrames: frames(40, 0.5, 0.1), closedFrames: frames(40, 0.5, 0.9), eye: "right" }).calibration
  const result = settingsFromCalibration(calibration, { stepMs: 3000 })
  assert.equal(result.ok, true)
  near(result.settings.closeThreshold, 0.58)
  near(result.settings.openThreshold, 0.3)
  assert.equal(result.settings.eye, "right")
  assert.equal(result.settings.stepMs, 3000)
  assert.equal(result.settings.holdMs, 800)
})

test("決まりを破る上書きをした設定は作らない", () => {
  const calibration = calibrate({ openFrames: frames(40, 0.1), closedFrames: frames(40, 0.9), eye: "both" }).calibration
  const result = settingsFromCalibration(calibration, { holdMs: 3000, restMs: 3000 })
  assert.equal(result.ok, false)
  assert.ok(result.errors.includes("holdTooCloseToRest"))
})

// ---- 保存値の検査 ----

const SAVED_AT = 1_800_000_000_000
const MODEL = "face_landmarker@1"
function savedRaw(overrides = {}) {
  const calibration = calibrate({ openFrames: frames(40, 0.1), closedFrames: frames(40, 0.9), eye: "both" }).calibration
  const saved = toSavedCalibration(calibration, { savedAt: SAVED_AT, modelVersion: MODEL, method: "hold3s" })
  return JSON.stringify({ ...saved, ...overrides })
}
const check = (raw, hoursLater = 1) =>
  checkSavedCalibration(raw, { now: SAVED_AT + hoursLater * HOUR_MS, modelVersion: MODEL })

test("保存する中身は 値・保存日時・版・調整方式・モデルの版・使う目 だけ（ユーザー ID を入れない）", () => {
  const saved = JSON.parse(savedRaw())
  assert.deepEqual(Object.keys(saved).sort(), [
    "closeThreshold", "closed", "eye", "method", "modelVersion", "open", "openThreshold", "savedAt", "version"
  ])
  assert.equal(saved.version, 1)
  assert.equal(saved.savedAt, SAVED_AT)
})

test("新しくて正しい保存値は使える", () => {
  const result = check(savedRaw(), 11.99)
  assert.equal(result.status, "ok")
  near(result.calibration.closeThreshold, 0.58)
  near(result.calibration.openThreshold, 0.3)
  assert.equal(result.calibration.eye, "both")
})

test("保存から 12 時間ちょうどたった保存値は古い", () => {
  assert.deepEqual(check(savedRaw(), 12), { status: "stale" })
  assert.deepEqual(check(savedRaw(), 30), { status: "stale" })
})

test("保存値が無ければ missing", () => {
  assert.deepEqual(check(null), { status: "missing" })
  assert.deepEqual(check(undefined), { status: "missing" })
})

test("壊れた保存値は使わない", () => {
  const broken = [
    "{not json",
    "null",
    "[]",
    "42",
    savedRaw({ version: 2 }),
    savedRaw({ savedAt: "yesterday" }),
    savedRaw({ savedAt: SAVED_AT + 2 * HOUR_MS }),
    savedRaw({ eye: "middle" }),
    savedRaw({ closeThreshold: null }),
    savedRaw({ openThreshold: 0.57 }),
    savedRaw({ closeThreshold: 0.95 }),
    savedRaw({ open: "0.1" }),
    savedRaw({ modelVersion: "face_landmarker@2" })
  ]
  for (const raw of broken) assert.deepEqual(check(raw), { status: "invalid" }, raw)
})

// 数値としては読めるが、意味が通らない調整結果。[説明, 上書きする値, 設定作成で返る理由]
// もとの値は O=0.1 / C=0.9 / 閉じ 0.58 / 開き 0.3
const MEANINGLESS = [
  ["開きしきい値が 0 より小さい", { openThreshold: -1 }, "openThresholdOutOfRange"],
  ["開きしきい値が 1 より大きい", { openThreshold: 1.2, closeThreshold: 0.9, closed: 0.95 }, "openThresholdOutOfRange"],
  ["開いた目のスコアが 0 より小さい", { open: -0.1 }, "openOutOfRange"],
  ["閉じた目のスコアが 1 より大きい", { closed: 1.2 }, "closedOutOfRange"],
  ["開いた目と閉じた目のスコアが逆", { open: 0.9, closed: 0.1 }, "lowContrast"],
  ["開いた目と閉じた目の差が 0.29 に足りない", { open: 0.5, closed: 0.7, closeThreshold: 0.62, openThreshold: 0.52 }, "lowContrast"],
  ["開きしきい値が、開いた目のスコアより低い", { open: 0.4, openThreshold: 0.3 }, "openThresholdBelowOpen"],
  ["閉じしきい値が、閉じた目のスコアより高い", { closed: 0.5, closeThreshold: 0.58 }, "closeThresholdAboveClosed"]
]

for (const [label, overrides, error] of MEANINGLESS) {
  test(`意味が通らない保存値は使わない: ${label}`, () => {
    assert.deepEqual(check(savedRaw(overrides)), { status: "invalid" })
  })

  test(`意味が通らない調整結果からは設定を作らない: ${label}`, () => {
    const calibration = { ...JSON.parse(savedRaw()), ...overrides }
    const result = settingsFromCalibration(calibration)
    assert.equal(result.ok, false)
    assert.ok(result.errors.includes(error), `${error} が入っている: ${result.errors}`)
  })
}

test("保存値の検査を通った調整結果からは、必ず設定を作れる", () => {
  const result = check(savedRaw())
  assert.equal(result.status, "ok")
  assert.equal(settingsFromCalibration(result.calibration).ok, true)
})

test("しきい値がスコアの端（開き = O、閉じ = C）にちょうど重なる調整結果は通す", () => {
  const overrides = { open: 0.3, closed: 0.58 }
  assert.equal(check(savedRaw(overrides)).status, "ok")
  assert.equal(settingsFromCalibration({ ...JSON.parse(savedRaw()), ...overrides }).ok, true)
})

test("開きしきい値が 0〜1 の外にある設定は拒否する", () => {
  assert.ok(validateSettings({ ...VALID, openThreshold: -0.2 }).errors.includes("openThresholdOutOfRange"))
  assert.ok(validateSettings({ ...VALID, closeThreshold: 0.9, openThreshold: 0 }).ok)
})

test("保存値に余計な項目が混ざっていても、返す調整結果には含めない", () => {
  const result = check(savedRaw({ userId: 42 }))
  assert.equal(result.status, "ok")
  assert.equal("userId" in result.calibration, false)
})
