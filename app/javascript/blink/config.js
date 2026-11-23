// まばたき入力の初期値と調整範囲を1か所にまとめる。
// 閉じ/開きのしきい値はここに置かない。人によって違うので、調整（calibration.js）して初めて決まる。

export const EYES = Object.freeze(["both", "right", "left"])

export const DEFAULTS = Object.freeze({
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
})

export const RANGES = Object.freeze({
  holdMs: Object.freeze({ min: 400, max: 3000, step: 100 }),
  closeThreshold: Object.freeze({ min: 0.2, max: 0.9 }),
  armingMs: Object.freeze({ min: 200, max: 1000 }),
  refractoryMs: Object.freeze({ min: 300, max: 2000 }),
  restMs: Object.freeze({ min: 3000, max: 15000 }),
  faceLostGraceMs: Object.freeze({ min: 100, max: 1000 }),
  stepMs: Object.freeze({ min: 800, max: 5000 }),
  firstStepRatio: Object.freeze({ min: 1, max: 2 }),
  autoPauseRounds: Object.freeze({ min: 1, max: 10, step: 1 }),
  confirmRounds: Object.freeze({ min: 1, max: 5, step: 1 }),
  calibrationStaleHours: Object.freeze({ min: 1, max: 48 })
})

// 目の「閉じ具合」のスコアと、そのしきい値が取りうる範囲
export const SCORE_RANGE = Object.freeze({ min: 0, max: 1 })

// 利用者が調整しない値
export const FIXED = Object.freeze({
  maxFrameGapMs: 250,
  maxResultAgeMs: 300,
  watchdogMs: 500,
  // 顔の連続性。設計書に数値が無いための仮の値で、実機の記録を見て決め直す。
  // 直前のフレームから、顔の中心が「顔の大きさ × 0.5」より大きく動くか、
  // 顔の大きさが 1.3 倍（または 1/1.3）を超えて変わったら、別の顔に切り替わった疑いとみなす。
  faceShiftRatio: 0.5,
  faceSizeRatio: 1.3
})

export const THRESHOLD_RULES = Object.freeze({
  closeRatio: 0.6,
  openRatio: 0.25,
  // 閉じしきい値 − 開きしきい値 ≧ 0.1（ちょうど 0.1 は通す）
  minGap: 0.1,
  // C − O ≧ 0.29（ちょうど 0.29 は通す。この時しきい値の差がほぼ 0.1 になる）
  minContrast: 0.29,
  holdRestMarginMs: 1000
})

export const CALIBRATION = Object.freeze({
  storageKey: "mabatalk.blink.v1",
  version: 1,
  // 3 秒の計測のうち、少なくともこれだけ有効なフレームが要る（約 10fps 相当）
  minFrames: 30,
  // ばらつきの重なりを見る時、開いた目は上位 1 割、閉じた目は下位 1 割を外れ値として除く
  // （40 件なら 4 件ずつ。件数 × 0.1 の端数は切り捨て）
  outlierRatio: 0.1
})
