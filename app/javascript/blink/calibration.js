// 調整（しきい値の計算）、値どうしの決まりの検査、片目のすすめ、保存値の検査。
// どれも引数だけで結果が決まる関数。localStorage の読み書きはここではしない。

import { CALIBRATION, DEFAULTS, EYES, RANGES, THRESHOLD_RULES } from "./config.js"
import { eyeScore } from "./blink_switch.js"

const EPSILON = 1e-9
const HOUR_MS = 60 * 60 * 1000
const isNumber = (value) => typeof value === "number" && Number.isFinite(value)

// O（開いた目のスコア）と C（閉じた目のスコア）から、閉じ/開きのしきい値を作る。
export function computeThresholds(open, closed) {
  if (!isNumber(open) || !isNumber(closed)) return { ok: false, reason: "notNumeric" }
  const contrast = closed - open
  if (contrast < THRESHOLD_RULES.minContrast - EPSILON) return { ok: false, reason: "lowContrast" }
  const closeThreshold = open + THRESHOLD_RULES.closeRatio * contrast
  const openThreshold = open + THRESHOLD_RULES.openRatio * contrast
  if (!inRange(closeThreshold, RANGES.closeThreshold)) return { ok: false, reason: "thresholdOutOfRange" }
  return { ok: true, closeThreshold, openThreshold }
}

// 開いた目・閉じた目を数秒ずつ撮ったフレーム（{ leftScore, rightScore } の並び）から調整結果を作る。
// 失敗した時は、代わりに使えそうな片目（無ければ null = タップ/介助者操作）を suggestedEye で返す。
export function calibrate({ openFrames, closedFrames, eye }) {
  const result = measure(openFrames, closedFrames, eye)
  if (result.ok) {
    const { eye: usedEye, open, closed, closeThreshold, openThreshold } = result
    return { ok: true, calibration: { eye: usedEye, open, closed, closeThreshold, openThreshold } }
  }
  return { ok: false, reason: result.reason, suggestedEye: suggestEye(openFrames, closedFrames, eye) }
}

function measure(openFrames, closedFrames, eye) {
  const openScores = validScores(openFrames, eye)
  const closedScores = validScores(closedFrames, eye)
  if (openScores.length < CALIBRATION.minFrames || closedScores.length < CALIBRATION.minFrames) {
    return { ok: false, reason: "insufficientFrames" }
  }
  const open = median(openScores)
  const closed = median(closedScores)
  const thresholds = computeThresholds(open, closed)
  if (!thresholds.ok) return thresholds
  const openHigh = percentile(openScores, CALIBRATION.spreadPercentile)
  const closedLow = percentile(closedScores, 1 - CALIBRATION.spreadPercentile)
  if (openHigh >= closedLow) return { ok: false, reason: "overlap" }
  return { ok: true, eye, open, closed, contrast: closed - open, ...thresholds }
}

function suggestEye(openFrames, closedFrames, currentEye) {
  const usable = ["right", "left"]
    .filter((eye) => eye !== currentEye)
    .map((eye) => measure(openFrames, closedFrames, eye))
    .filter((result) => result.ok)
    .sort((a, b) => b.contrast - a.contrast)
  return usable.length > 0 ? usable[0].eye : null
}

function validScores(frames, eye) {
  if (!Array.isArray(frames)) return []
  return frames
    .map((frame) => eyeScore(frame, eye))
    .filter((score) => score !== null)
    .sort((a, b) => a - b)
}

function median(sorted) {
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

// 小さい順に並んだ値の、下から ratio の位置にある値（nearest-rank）
function percentile(sorted, ratio) {
  const rank = Math.ceil(ratio * sorted.length - EPSILON)
  return sorted[Math.min(sorted.length, Math.max(1, rank)) - 1]
}

function inRange(value, range) {
  if (!isNumber(value)) return false
  if (value < range.min - EPSILON || value > range.max + EPSILON) return false
  if (range.step && Math.abs(value / range.step - Math.round(value / range.step)) > EPSILON) return false
  return true
}

// 設定（初期値 + 調整したしきい値 + 利用者の上書き）が、調整範囲と値どうしの決まりを守っているか。
// 1つでも破っていれば ok: false と、破った決まりの名前の一覧を返す。
export function validateSettings(settings) {
  const errors = []
  const calibrated = isNumber(settings.closeThreshold) && isNumber(settings.openThreshold)
  if (!calibrated) errors.push("notCalibrated")
  if (!EYES.includes(settings.eye)) errors.push("eyeInvalid")

  for (const [field, range] of Object.entries(RANGES)) {
    if (field === "closeThreshold" && !calibrated) continue
    if (field === "firstStepRatio" && isNumber(settings[field]) && settings[field] < range.min) continue
    if (!inRange(settings[field], range)) errors.push(`${field}OutOfRange`)
  }

  if (calibrated && settings.closeThreshold - settings.openThreshold < THRESHOLD_RULES.minGap - EPSILON) {
    errors.push("thresholdGapTooSmall")
  }
  if (settings.holdMs + THRESHOLD_RULES.holdRestMarginMs > settings.restMs) errors.push("holdTooCloseToRest")
  if (settings.stepMs * settings.firstStepRatio < settings.stepMs) errors.push("firstStepShorterThanStep")

  return { ok: errors.length === 0, errors }
}

// 調整結果が無ければ設定を作らない。まばたき入力は、この関数が ok を返した設定でだけ始める。
export function settingsFromCalibration(calibration, overrides = {}) {
  if (!calibration) return { ok: false, errors: ["notCalibrated"] }
  const settings = {
    ...DEFAULTS,
    ...overrides,
    eye: calibration.eye,
    closeThreshold: calibration.closeThreshold,
    openThreshold: calibration.openThreshold
  }
  const { ok, errors } = validateSettings(settings)
  return ok ? { ok: true, settings } : { ok: false, errors }
}

// 端末に保存する中身。誰の値かを示すもの（ユーザー ID など）は入れない。
export function toSavedCalibration(calibration, { savedAt, modelVersion, method }) {
  return {
    version: CALIBRATION.version,
    savedAt,
    method,
    modelVersion,
    eye: calibration.eye,
    open: calibration.open,
    closed: calibration.closed,
    closeThreshold: calibration.closeThreshold,
    openThreshold: calibration.openThreshold
  }
}

// 保存してあった文字列（無ければ null）を検査する。now と savedAt は Date.now() と同じ時計（エポックミリ秒）。
// 戻り値の status: "ok"（calibration つき）/ "missing" / "stale"（古い）/ "invalid"（壊れている・使えない）
export function checkSavedCalibration(raw, { now, modelVersion, staleHours = DEFAULTS.calibrationStaleHours }) {
  if (raw === null || raw === undefined) return { status: "missing" }
  const saved = parseJson(raw)
  if (!isValidSaved(saved, now, modelVersion)) return { status: "invalid" }
  if (now - saved.savedAt >= staleHours * HOUR_MS) return { status: "stale" }
  return {
    status: "ok",
    calibration: {
      eye: saved.eye,
      open: saved.open,
      closed: saved.closed,
      closeThreshold: saved.closeThreshold,
      openThreshold: saved.openThreshold
    }
  }
}

function parseJson(raw) {
  try {
    return JSON.parse(raw)
  } catch {
    return null
  }
}

function isValidSaved(saved, now, modelVersion) {
  if (saved === null || typeof saved !== "object" || Array.isArray(saved)) return false
  if (saved.version !== CALIBRATION.version) return false
  if (!isNumber(saved.savedAt) || saved.savedAt > now) return false
  if (typeof saved.method !== "string" || saved.method === "") return false
  if (saved.modelVersion !== modelVersion) return false
  if (!EYES.includes(saved.eye)) return false
  if (!isNumber(saved.open) || !isNumber(saved.closed)) return false
  if (!inRange(saved.closeThreshold, RANGES.closeThreshold) || !isNumber(saved.openThreshold)) return false
  return saved.closeThreshold - saved.openThreshold >= THRESHOLD_RULES.minGap - EPSILON
}
