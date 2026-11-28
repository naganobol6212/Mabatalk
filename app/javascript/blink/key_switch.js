// キー・タップを「長いまばたき 1 回」として扱う入力源。DOM もタイマーも時計も持たない。
// blink_switch（カメラのまばたき判定）と同じ形で結果を出すので、画面側は入力源を差し替えられる:
//   phase  … "open"（受付中）/ "refractory"（安定待ち）。scan_sequencer の eyePhase にそのまま渡す
//   events … { type: "select", key }（押した時に光っていた項目の決定）
//
// 入力:
//   { type: "press", now, highlightedKey }  押した（何も光っていなければ key は null）
//   { type: "tick", now }                   時計を進める
//
// 押したあとは settings.refractoryMs のあいだ安定待ちになり、そのあいだの押下は捨てる
// （続けて 2 回押してしまっても 1 回。確認の「いいえ」が光り始めるのも、安定待ちが明けてから）。
// まばたきのしきい値・使う目は使わない。

const isTime = (value) => typeof value === "number" && Number.isFinite(value)

export function createKeySwitch() {
  return { phase: "open", since: null }
}

export function stepKeySwitch(state, input, settings) {
  if (!isTime(input.now)) return { state, events: [] }
  const current = settled(state, input.now, settings)
  if (input.type !== "press" || current.phase !== "open") return { state: current, events: [] }
  return {
    state: { phase: "refractory", since: input.now },
    events: [{ type: "select", key: input.highlightedKey ?? null }]
  }
}

function settled(state, now, settings) {
  if (state.phase !== "refractory" || now - state.since < settings.refractoryMs) return state
  return createKeySwitch()
}

// 画面側が持つ入力源。結果は scan_session へ { type: "switch", ...結果 } として渡す。
export function createKeySource(settings) {
  let state = createKeySwitch()
  const step = (input) => {
    const stepped = stepKeySwitch(state, input, settings)
    state = stepped.state
    return { now: input.now, phase: state.phase, events: stepped.events }
  }
  return {
    press: (now, highlightedKey) => step({ type: "press", now, highlightedKey }),
    tick: (now) => step({ type: "tick", now }),
    reset() { state = createKeySwitch() }
  }
}

// keydown をスキャン入力として扱うか。
//   "press"   … 押した（Space / Enter）
//   "swallow" … 押しっぱなしのくり返し。押したことにはしないが、画面がスクロールしないようキーは受け取る
//   "ignore"  … スキャン入力ではない（ブラウザのふつうの動きに任せる）
// onControl: フォーカスがボタン・リンク・入力欄などにある（介助者がふつうに押せるよう、スキャン入力にしない）
// 修飾キー（Ctrl・Alt・Cmd・Shift）付きは、ブラウザの操作（Shift+Space は上へのスクロールなど）なので除く
export function keyIntent({ key, repeat, altKey, ctrlKey, metaKey, shiftKey, onControl }) {
  if (onControl || altKey || ctrlKey || metaKey || shiftKey) return "ignore"
  if (key !== " " && key !== "Enter") return "ignore"
  return repeat ? "swallow" : "press"
}
