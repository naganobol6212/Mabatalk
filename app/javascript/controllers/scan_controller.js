import { Controller } from "@hotwired/stimulus"
import { FIXED } from "../blink/config.js"
import { createKeySource, keyIntent } from "../blink/key_switch.js"
import { createScanSession, scanView, sendOutcome, stepScanSession, timingSettings } from "../blink/scan_session.js"

// まばたきスキャン画面。状態の進め方は blink/scan_session.js（DOM なし）に任せ、
// ここは「入力を渡す・時計を回す・記録を送る・画面に出す」だけをする。
//
// 入力源: PR2 はキーとタップ（blink/key_switch.js）。入力源の結果 { now, phase, events } を
// deliver() に渡せば同じ選択処理に入るので、PR3b のカメラ（blink_switch）も同じ口につなぐ。
const TICK_MS = 50
const CONTROLS = "a[href], button, input, select, textarea, summary, [contenteditable]:not([contenteditable='false']), [role='button']"
const SCANNING_SCREENS = ["scanning", "confirming", "paused"]
const IDLE_VIEW = { screen: "idle", highlightedKey: null, pendingKey: null, done: null, haltReason: null, failures: 0 }

export default class extends Controller {
  static targets = [
    "stage", "item", "highlightable", "panel", "startButton", "stopButton",
    "pendingName", "doneName", "guestNote", "repeatedNote", "haltReason"
  ]
  static values = { url: String, settings: Object }
  static classes = ["highlight"]

  connect() {
    this.session = null
    this.render()
  }

  // ページを離れる・Turbo が画面を外す時。タイマーと送信を片付け、あとから届く返事も使わない
  disconnect() {
    this.apply({ type: "stop" })
    this.session = null
  }

  start() {
    if (!this.session) this.prepare()
    this.apply({ type: "start" })
    // 押した「開始」ボタンは隠れる。そのあとのキーがスキャン入力になるよう、スキャン領域へフォーカスを移す
    if (this.view.screen !== "idle") this.stageTarget.focus()
  }

  stop() {
    this.apply({ type: "stop" })
    this.startButtonTarget.focus()
  }

  retry() {
    this.apply({ type: "retry" })
  }

  reload() {
    window.location.reload()
  }

  suspend() {
    this.apply({ type: "suspend" })
  }

  visibilityChanged() {
    this.apply({ type: document.hidden ? "suspend" : "resume" })
  }

  // 履歴で戻ってきた時など。前の閉眼・押下・「はい」の候補を持ち越さないよう、いったん止めてからやり直す
  pageShown() {
    this.apply({ type: "suspend" })
    if (!document.hidden) this.apply({ type: "resume" })
  }

  keydown(event) {
    const onControl = event.target instanceof Element && event.target.closest(CONTROLS) !== null
    const intent = keyIntent({
      key: event.key,
      repeat: event.repeat,
      altKey: event.altKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
      shiftKey: event.shiftKey,
      onControl
    })
    if (intent === "ignore" || !SCANNING_SCREENS.includes(this.view.screen)) return
    event.preventDefault()
    if (intent === "press") this.press()
  }

  tap(event) {
    if (event.target instanceof Element && event.target.closest(CONTROLS)) return
    this.press()
  }

  // 入力源の結果を、選択処理へ渡す口
  deliver(result) {
    this.apply({ type: "switch", ...result })
  }

  press() {
    if (this.session) this.deliver(this.source.press(performance.now(), this.view.highlightedKey))
  }

  tick() {
    this.deliver(this.source.tick(performance.now()))
  }

  get view() {
    return this.session ? scanView(this.session) : IDLE_VIEW
  }

  prepare() {
    const settings = timingSettings(this.readSettings())
    const items = this.itemTargets.map(({ dataset }) => ({ key: dataset.key, kind: dataset.kind }))
    const created = createScanSession({ items, settings, newSubmissionId: () => crypto.randomUUID() })
    if (!created.ok) return
    this.session = created.state
    this.source = createKeySource(settings)
  }

  readSettings() {
    try {
      return this.settingsValue
    } catch {
      return {}
    }
  }

  apply(input) {
    if (!this.session) return
    const stepped = stepScanSession(this.session, input)
    this.session = stepped.state
    for (const effect of stepped.effects) {
      if (effect.type === "send") this.send(effect)
      if (effect.type === "cancelSend") this.abortSend?.abort()
      if (effect.type === "resetInput") this.source.reset()
    }
    this.syncClock()
    this.render()
  }

  // 時計（50ms ごとの tick）は、スキャン中と完了表示のあいだだけ回す
  syncClock() {
    const needed = SCANNING_SCREENS.includes(this.view.screen) || this.view.screen === "done"
    if (needed && !this.clock) this.clock = setInterval(() => this.tick(), TICK_MS)
    if (!needed && this.clock) {
      clearInterval(this.clock)
      this.clock = null
    }
  }

  // 返事が来ない時は sendTimeoutMs（10 秒）で打ち切る。通信エラー・時間切れ・読めない返事は「届いたか不明」
  async send({ attempt, flowItemKey, submissionId }) {
    const abort = new AbortController()
    this.abortSend = abort
    const timeout = setTimeout(() => abort.abort(), FIXED.sendTimeoutMs)
    let response = null
    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content ?? ""
        },
        body: JSON.stringify({ flow_item_key: flowItemKey, submission_id: submissionId }),
        signal: abort.signal
      })
      response = { status: res.status, body: await res.json().catch(() => null) }
    } catch {
      response = null
    } finally {
      clearTimeout(timeout)
    }
    this.apply({ type: "sendResult", now: performance.now(), attempt, outcome: sendOutcome(response) })
  }

  render() {
    const view = this.view
    const signature = JSON.stringify(view)
    if (signature === this.rendered) return
    this.rendered = signature

    for (const panel of this.panelTargets) panel.hidden = !panel.dataset.screens.split(" ").includes(view.screen)
    this.startButtonTarget.hidden = view.screen !== "idle"
    this.stopButtonTarget.hidden = view.screen === "idle" || view.screen === "halted"

    for (const element of this.highlightableTargets) {
      const on = element.dataset.key === view.highlightedKey
      for (const name of this.highlightClasses) element.classList.toggle(name, on)
      element.toggleAttribute("data-highlighted", on)
    }

    // 名前は文字として入れる（HTML として解釈させない）
    const pendingName = this.itemTargets.find((item) => item.dataset.key === view.pendingKey)?.dataset.name ?? ""
    for (const element of this.pendingNameTargets) element.textContent = pendingName
    this.doneNameTarget.textContent = view.done?.name ?? ""
    this.guestNoteTarget.hidden = !view.done || view.done.savedToHistory
    this.repeatedNoteTarget.hidden = view.failures < 2
    for (const element of this.haltReasonTargets) element.hidden = element.dataset.reason !== view.haltReason
  }
}
