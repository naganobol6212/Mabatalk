// まばたきスキャン PR0.5：iPad 実機で Worker 版と画面側版を同じ条件で比べる計測ページ。
// 映像・画像・連続したスコアは保存しない・送らない。保存するのは時間の数字と集計だけ（この端末の localStorage）。
import { WorkerEngine, MainEngine } from "./engines.js";
import { VERSIONS } from "./face_common.js";
import { CRITERIA, LIMITS, evaluate } from "./criteria.js";

const PAGE_VERSION = "2026-11-29.1";
const STORE_KEY = "mabatalk.blinkMeasure.v1";
const MIN_GAP_MS = 1000 / LIMITS.targetFps - 12; // 30fps のカメラから毎秒 15 回を取り出すための間隔
const params = new URLSearchParams(location.search);
const SOURCE = params.get("source") || "camera"; // Mac での確認用に image（公開のテスト画像）も選べる

const $ = (id) => document.getElementById(id);
const videoEl = $("video");
const fmt = (v, d = 0) => (v == null || Number.isNaN(v) ? "—" : Number(v).toFixed(d));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const round1 = (v) => (v == null ? null : Math.round(v * 10) / 10);
const round3 = (v) => (v == null || Number.isNaN(v) ? null : Number(v.toFixed(3)));
const WARMUP_MS = 2000; // 最初の 2 秒（GPU の準備など）は「落ちたフレーム」の判定から外し、別に数える

// ---------- 集計 ----------
function pct(arr) {
  const n = arr.length;
  if (!n) return { n: 0 };
  const a = Float64Array.from(arr).sort();
  const q = (p) => a[Math.min(n - 1, Math.round(p * (n - 1)))];
  let sum = 0;
  for (const v of a) sum += v;
  return { n, p50: round1(q(0.5)), p95: round1(q(0.95)), p99: round1(q(0.99)), max: round1(a[n - 1]), min: round1(a[0]), mean: round1(sum / n) };
}
const median = (arr) => (arr.length ? pct(arr).p50 : null);

// ---------- 保存（この端末だけ） ----------
function loadStore() {
  try {
    const s = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    if (s && Array.isArray(s.runs)) return s;
  } catch { /* 読めなくても動く */ }
  return { runs: [], manual: {}, thresholds: null };
}
const store = loadStore();
function saveStore() {
  try {
    let json = JSON.stringify(store);
    // 大きくなりすぎたら古い回のフレーム記録から捨てる
    for (let i = 0; json.length > 4_000_000 && i < store.runs.length; i++) {
      delete store.runs[i].frames;
      json = JSON.stringify(store);
    }
    localStorage.setItem(STORE_KEY, json);
  } catch { /* プライベートブラウズなどで保存できなくても、画面の結果とコピーは使える */ }
}

// ---------- 端末の情報 ----------
function webglInfo() {
  try {
    const c = document.createElement("canvas");
    const gl = c.getContext("webgl2") || c.getContext("webgl");
    if (!gl) return null;
    const ext = gl.getExtension("WEBGL_debug_renderer_info");
    return {
      version: gl.getParameter(gl.VERSION),
      vendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
      renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
    };
  } catch {
    return null;
  }
}
function deviceInfo() {
  const ua = navigator.userAgent;
  const m = ua.match(/Version\/([\d.]+).*Safari/);
  return {
    userAgent: ua,
    looksLikeIPad: /iPad/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1),
    safariVersion: m ? m[1] : null,
    standalone: window.matchMedia?.("(display-mode: standalone)").matches || navigator.standalone === true,
    screen: { w: screen.width, h: screen.height, dpr: devicePixelRatio },
    hardwareConcurrency: navigator.hardwareConcurrency ?? null,
    deviceMemory: navigator.deviceMemory ?? null,
    webgl: webglInfo(),
    features: {
      offscreenCanvas: typeof OffscreenCanvas !== "undefined",
      requestVideoFrameCallback: "requestVideoFrameCallback" in HTMLVideoElement.prototype,
      wakeLock: "wakeLock" in navigator,
      moduleWorker: true,
    },
    source: SOURCE,
  };
}
const MANUAL_FIELDS = ["model", "os", "launch", "charging", "batteryStart", "batteryEnd", "heat", "note"];
function readManual() {
  const o = {};
  for (const k of MANUAL_FIELDS) o[k] = $(`m-${k}`).value;
  return o;
}

// ---------- 置き場所 ----------
function paths(cold) {
  const base = cold ? `vendor-bust/${Date.now()}` : "vendor";
  const abs = (p) => new URL(`./${base}/${p}`, location.href).href;
  return {
    bundleUrl: abs("tasks-vision/vision_bundle.mjs"),
    wasmBase: abs("tasks-vision/wasm"),
    modelUrl: abs("models/face_landmarker.task"),
  };
}

// ---------- 音（合図） ----------
let audioCtx = null;
function ensureAudio() {
  try {
    audioCtx ||= new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === "suspended") audioCtx.resume();
  } catch { /* 音が出なくても画面の合図で進める */ }
}
function beep(freq, ms) {
  if (!audioCtx) return;
  const o = audioCtx.createOscillator();
  const g = audioCtx.createGain();
  o.frequency.value = freq;
  g.gain.value = 0.15;
  o.connect(g).connect(audioCtx.destination);
  o.start();
  o.stop(audioCtx.currentTime + ms / 1000);
}
function cue(text) {
  $("cue").textContent = text || "";
  $("cue").hidden = !text;
}

// ---------- 画面のスリープ ----------
let wakeLock = null;
async function requestWakeLock() {
  try {
    if ("wakeLock" in navigator && !document.hidden) wakeLock = await navigator.wakeLock.request("screen");
    return true;
  } catch {
    return false;
  }
}

// ---------- カメラ ----------
async function imageStream() {
  const img = new Image();
  img.src = "vendor/test/face.jpg";
  await img.decode();
  const c = document.createElement("canvas");
  c.width = 640;
  c.height = 480;
  const ctx = c.getContext("2d");
  const s = Math.max(640 / img.width, 480 / img.height);
  let alive = true;
  const draw = () => {
    if (!alive) return;
    ctx.drawImage(img, (640 - img.width * s) / 2, (480 - img.height * s) / 2, img.width * s, img.height * s);
    requestAnimationFrame(draw);
  };
  draw();
  const stream = c.captureStream(30);
  stream.getTracks()[0].addEventListener("ended", () => { alive = false; });
  const origStop = MediaStreamTrack.prototype.stop;
  stream.getTracks()[0].stop = function stop() { alive = false; origStop.call(this); };
  return stream;
}
async function openCamera() {
  const stream =
    SOURCE === "image"
      ? await imageStream()
      : await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: "user", width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 } },
      });
  videoEl.srcObject = stream;
  await videoEl.play();
  if (videoEl.readyState < 2) await new Promise((r) => videoEl.addEventListener("loadeddata", r, { once: true }));
  return stream;
}
function stopStream(stream) {
  if (!stream) return true;
  for (const t of stream.getTracks()) t.stop();
  videoEl.srcObject = null;
  return stream.getTracks().every((t) => t.readyState === "ended");
}
function trackSettings(stream) {
  const s = stream?.getVideoTracks()[0]?.getSettings?.() || {};
  return { width: s.width ?? videoEl.videoWidth, height: s.height ?? videoEl.videoHeight, frameRate: s.frameRate ?? null, facingMode: s.facingMode ?? null };
}

// ---------- 1 回分の計測 ----------
let run = null;
let pageStarts = 0;
let abortSequence = false;
let sequenceActive = false;

function newBucket(idx) {
  return { idx, lat: [], proc: [], iv: [], raf: [], results: 0, valid: 0, stale: 0, over250: 0, watchdog: 0 };
}

function newRun(cfg) {
  pageStarts++;
  let finish;
  const r = {
    cfg,
    id: `${Date.now().toString(36)}`,
    startedAt: new Date().toISOString(),
    finished: new Promise((res) => { finish = res; }),
    _finish: finish,
    done: false,
    suspended: false,
    userStopped: false,
    transition: Promise.resolve(),
    gen: 1,
    seq: 0,
    lastSeq: 0,
    inFlight: null,
    lastSendTs: -1e9,
    lastValidTs: null,
    lastAnyRecv: null,
    awaitingFirst: true,
    resumeT0: null,
    measureStart: null,
    stream: null,
    engine: null,
    ok: false,
    error: null,
    startup: {},
    c: { cameraFrames: 0, sent: 0, results: 0, valid: 0, busySkips: 0, throttled: 0, stale: 0, noFace: 0, noScore: 0, errors: 0, genDiscard: 0, outOfOrder: 0, watchdog: 0, watchdogWarmup: 0, missedCameraFrames: 0, lost: 0, stalls1s: 0, stalls1sWarmup: 0, over250: 0, faceFrames: 0, scoreFrames: 0 },
    a: { lat: [], proc: [], grab: [], iv: [], raf: [], scanLate: [], tap: [], camLag: [] },
    scoreMin: 1,
    scoreMax: 0,
    hist: new Array(20).fill(0),
    minute: newBucket(0),
    minutes: [],
    frames: [],
    events: [],
    sampleSink: null,
    hold: { state: "arm", start: 0, started: 0, long: 0, short: 0, canceled: { gap: 0, invalid: 0, stale: 0, watchdog: 0, suspend: 0 } },
    blink: {},
    ui: {},
    resume: { attempts: 0, successes: 0, resumeMs: [], errors: [], events: [] },
    restart: { isRestart: pageStarts > 1, index: pageStarts },
    memStart: performance.memory?.usedJSHeapSize ?? null,
    lastError: null,
  };
  return r;
}

function thresholds() {
  return store.thresholds || { closeThr: 0.5, openThr: 0.3, provisional: true };
}

// 保持（長いまばたき）の試算。PR1 の判定モジュールそのものではなく、速さが保持を壊すかを見るための簡易版。
function holdOnValid(r, ts, avg, iv) {
  const h = r.hold;
  const { closeThr, openThr } = thresholds();
  if (h.state === "closed") {
    if (iv != null && iv > LIMITS.gapMs) return holdCancel(r, "gap", ts);
    if (avg <= openThr) {
      const dur = ts - h.start;
      if (dur >= LIMITS.holdMs) { h.long++; r.events.push({ t: ts, type: "long", dur }); }
      else { h.short++; r.events.push({ t: ts, type: "short", dur }); }
      h.state = "arm";
    }
  } else if (h.state === "waitOpen") {
    if (avg <= openThr) h.state = "arm";
  } else if (avg >= closeThr) {
    h.state = "closed";
    h.start = ts;
    h.started++;
  }
}
function holdCancel(r, kind, ts = performance.now()) {
  const h = r.hold;
  if (h.state !== "closed") { if (kind === "suspend") h.state = "waitOpen"; return; }
  h.canceled[kind]++;
  h.state = "waitOpen";
  r.events.push({ t: ts, type: "cancel", kind });
}

function scheduleFrame(r) {
  if (r.done || r.suspended || r !== run) return;
  if ("requestVideoFrameCallback" in videoEl) videoEl.requestVideoFrameCallback((_now, meta) => onFrame(r, meta));
  else requestAnimationFrame(() => onFrame(r, null));
}

function onFrame(r, meta) {
  if (r.done || r.suspended || r !== run) return;
  scheduleFrame(r);
  r.c.cameraFrames++;
  // 参考：カメラの撮影時刻が取れるブラウザだけ、撮影→コールバックの遅れと、見逃したカメラフレームを記録
  if (meta?.captureTime) r.a.camLag.push(performance.now() - meta.captureTime);
  if (meta?.presentedFrames != null) {
    if (r.lastPresented != null && meta.presentedFrames - r.lastPresented > 1) r.c.missedCameraFrames += meta.presentedFrames - r.lastPresented - 1;
    r.lastPresented = meta.presentedFrames;
  }
  if (r.inFlight) { r.c.busySkips++; return; }
  const ts = performance.now(); // 撮影時刻（設計：performance.now()）
  if (ts - r.lastSendTs < MIN_GAP_MS) { r.c.throttled++; return; }
  sendFrame(r, ts);
}

async function sendFrame(r, ts) {
  const engine = r.engine;
  const f = { video: videoEl, ts, seq: ++r.seq, gen: r.gen };
  r.inFlight = f;
  r.lastSendTs = ts;
  r.c.sent++;
  const wd = setTimeout(() => {
    if (r.inFlight !== f) return;
    if (r.measureStart == null || performance.now() - r.measureStart < WARMUP_MS) r.c.watchdogWarmup++;
    else { r.c.watchdog++; r.minute.watchdog++; }
    holdCancel(r, "watchdog");
  }, LIMITS.watchdogMs);
  const lost = setTimeout(() => {
    if (r.inFlight === f) { r.c.lost++; r.inFlight = null; }
  }, 5000);
  let res;
  try {
    res = await engine.detect(f);
  } catch (err) {
    res = { seq: f.seq, gen: f.gen, procMs: 0, grabMs: 0, error: String(err?.message || err) };
  }
  clearTimeout(wd);
  clearTimeout(lost);
  if (r.inFlight === f) r.inFlight = null;
  onResult(r, f, res);
}

function closeBucket(r, partialSec) {
  const b = r.minute;
  r.minutes.push({
    minute: b.idx,
    seconds: partialSec ?? 60,
    results: b.results,
    valid: b.valid,
    validRate: round1(b.valid / (partialSec || 60)),
    intervalP95: pct(b.iv).p95 ?? null,
    intervalMax: pct(b.iv).max ?? null,
    latencyP95: pct(b.lat).p95 ?? null,
    procP50: pct(b.proc).p50 ?? null,
    procP95: pct(b.proc).p95 ?? null,
    rafP95: pct(b.raf).p95 ?? null,
    stale: b.stale,
    over250: b.over250,
    watchdog: b.watchdog,
    memMB: performance.memory ? round1(performance.memory.usedJSHeapSize / 1048576) : null,
  });
  r.minute = newBucket(b.idx + 1);
}

function onResult(r, f, res) {
  if (r !== run || r.done) return;
  const recv = performance.now();
  if (res.gen !== r.gen) { r.c.genDiscard++; return; }
  if (res.seq <= r.lastSeq) { r.c.outOfOrder++; return; }
  r.lastSeq = res.seq;

  if (r.awaitingFirst) {
    r.awaitingFirst = false;
    if (r.resumeT0 != null) {
      if (!res.error) { r.resume.successes++; r.resume.resumeMs.push(Math.round(recv - r.resumeT0)); }
      r.resumeT0 = null;
    } else {
      r.startup.firstDetectMs = round1(res.procMs + (res.grabMs || 0));
      r.startup.firstResultTotalMs = Math.round(recv - r.startup.t0);
      r.ok = !res.error;
      if (res.error) { r.error = `最初のフレームで失敗：${res.error}`; finishRun(r, "error"); return; }
      r.measureStart = recv;
    }
    r.lastAnyRecv = recv;
    return; // 最初の 1 回（シェーダーの準備などで遅い）は集計に入れず、firstDetectMs に記録する
  }

  while (recv - r.measureStart >= (r.minute.idx + 1) * 60000) closeBucket(r);
  const b = r.minute;
  r.c.results++;
  b.results++;
  if (r.lastAnyRecv != null && recv - r.lastAnyRecv > 1000) {
    if (recv - r.measureStart < WARMUP_MS) r.c.stalls1sWarmup++;
    else r.c.stalls1s++;
  }
  r.lastAnyRecv = recv;
  const age = recv - f.ts;
  r.a.lat.push(age);
  b.lat.push(age);
  r.a.proc.push(res.procMs);
  b.proc.push(res.procMs);
  if (res.grabMs) r.a.grab.push(res.grabMs);

  let valid = false;
  let reason = 0; // 0 有効 1 エラー 2 古い 3 顔なし 4 スコアなし
  if (res.error) { r.c.errors++; reason = 1; r.lastError = res.error; }
  else if (age > LIMITS.staleMs) { r.c.stale++; b.stale++; reason = 2; }
  else if (!res.faces) { r.c.noFace++; reason = 3; }
  else if (res.left == null || res.right == null) { r.c.noScore++; reason = 4; }
  else valid = true;
  if (res.faces) r.c.faceFrames++;
  if (res.faces && res.left != null && res.right != null) r.c.scoreFrames++;

  let iv = null;
  if (valid) {
    r.c.valid++;
    b.valid++;
    if (r.lastValidTs != null) {
      iv = f.ts - r.lastValidTs;
      r.a.iv.push(iv);
      b.iv.push(iv);
      if (iv > LIMITS.gapMs) { r.c.over250++; b.over250++; }
    }
    r.lastValidTs = f.ts;
    const avg = (res.left + res.right) / 2;
    r.scoreMin = Math.min(r.scoreMin, res.left, res.right);
    r.scoreMax = Math.max(r.scoreMax, res.left, res.right);
    r.hist[Math.min(19, Math.floor(avg * 20))]++;
    r.live = { left: res.left, right: res.right, avg, box: res.box };
    r.sampleSink?.push({ left: res.left, right: res.right, avg });
    holdOnValid(r, f.ts, avg, iv);
  } else {
    if (reason === 3 || reason === 4) r.lastValidTs = null; // 顔が消えた区間は速さの間隔に数えない
    holdCancel(r, reason === 2 ? "stale" : "invalid", f.ts);
    r.live = { left: null, right: null, avg: null, reason };
  }
  if (r.cfg.plannedSec <= 300 && r.frames.length < 6000) {
    r.frames.push([Math.round(f.ts - r.measureStart), Math.round(age), round1(res.procMs), reason]);
  }
}

// ---------- 画面の反応を測る ----------
function startProbes(r) {
  let last = null;
  const raf = () => {
    if (r.done) return;
    const now = performance.now();
    if (last != null && !r.suspended && !document.hidden) {
      const g = now - last;
      if (g < 2000) { r.a.raf.push(g); r.minute.raf.push(g); }
    }
    last = r.suspended || document.hidden ? null : now;
    requestAnimationFrame(raf);
  };
  requestAnimationFrame(raf);

  // スキャンの光を 2 秒ごとに動かし、予定時刻からの遅れ（描画の直前まで）を測る
  const cells = document.querySelectorAll(".scan-cell");
  let i = 0;
  let expected = performance.now() + 2000;
  const tick = () => {
    if (r.done) return;
    cells.forEach((c, k) => c.classList.toggle("on", k === i % cells.length));
    i++;
    const exp = expected;
    requestAnimationFrame(() => { if (!r.suspended && !document.hidden) r.a.scanLate.push(performance.now() - exp); });
    expected += 2000;
    r.scanTimer = setTimeout(tick, Math.max(0, expected - performance.now()));
  };
  r.scanTimer = setTimeout(tick, 2000);
}

// ---------- 開始・停止 ----------
async function startRun(cfg) {
  if (run && !run.done) return run;
  const r = newRun(cfg);
  run = r;
  setRunningUI(true, cfg);
  r.startup.t0 = performance.now();
  r.wakeLock = await requestWakeLock();
  try {
    const c0 = performance.now();
    r.stream = await openCamera();
    r.startup.cameraMs = Math.round(performance.now() - c0);
    r.video = trackSettings(r.stream);
    const p = paths(cfg.cold);
    r.engine = cfg.mode === "worker" ? new WorkerEngine(p) : new MainEngine(p);
    r.engine.onFatal = (msg) => { r.lastError = msg; };
    const info = await r.engine.init(cfg.delegate);
    Object.assign(r.startup, {
      importMs: Math.round(info.timings.importMs),
      filesetMs: Math.round(info.timings.filesetMs),
      createMs: Math.round(info.timings.createMs),
      resources: info.resources,
    });
    // WASM とモデルのダウンロード時間（トンネルの速さは本番と違うので、判定では差し引く）
    r.startup.downloadMs = info.resources.filter((x) => /\.(wasm|task)$/.test(x.file)).reduce((a, x) => a + (x.durationMs || 0), 0);
    const wasm = info.resources.find((x) => x.file.endsWith(".wasm"));
    r.startup.cold = !!cfg.cold || (wasm ? wasm.transferBytes > 1_000_000 : false);
    startProbes(r);
    scheduleFrame(r);
  } catch (err) {
    r.ok = false;
    r.error = String(err?.message || err);
    await finishRun(r, "error");
  }
  return r;
}

async function finishRun(r, reason) {
  if (r.done) return;
  r.done = true;
  r.stopReason = reason;
  clearTimeout(r.scanTimer);
  r.sampleSink = null;
  r.ui.tracksEnded = stopStream(r.stream);
  const closed = r.engine ? await r.engine.close() : { stopped: true };
  r.ui.engineStopped = closed.stopped;
  try { await wakeLock?.release(); } catch { /* 無視 */ }
  wakeLock = null;
  cue("");
  const summary = summarize(r);
  store.runs.push(summary);
  store.manual = readManual();
  saveStore();
  setRunningUI(false);
  renderResults(summary.id);
  r._finish(summary);
}

function summarize(r) {
  const measuredSec = r.measureStart ? (performance.now() - r.measureStart) / 1000 : 0;
  if (r.measureStart && r.minute.results) closeBucket(r, Math.round(measuredSec - r.minute.idx * 60));
  const c = r.c;
  const s = {
    id: r.id,
    label: `${r.cfg.mode === "worker" ? "Worker" : "画面側"}＋${r.cfg.delegate}`,
    mode: r.cfg.mode,
    delegate: r.cfg.delegate,
    plannedSec: r.cfg.plannedSec,
    purpose: r.cfg.purpose || null,
    startedAt: r.startedAt,
    durationSec: Math.round(measuredSec),
    ok: r.ok,
    error: r.error,
    lastError: r.lastError,
    stopReason: r.stopReason,
    wakeLock: r.wakeLock,
    video: r.video || null,
    startup: { ...r.startup, t0: undefined },
    stats: {
      counts: { ...c },
      validRate: measuredSec ? round1(c.valid / measuredSec) : null,
      resultRate: measuredSec ? round1(c.results / measuredSec) : null,
      validIntervalMs: pct(r.a.iv),
      latencyMs: pct(r.a.lat),
      procMs: pct(r.a.proc),
      grabMs: pct(r.a.grab),
      cameraToCallbackMs: pct(r.a.camLag), // 取れない端末では n=0
    },
    ui: {
      ...r.ui,
      rafGapMs: pct(r.a.raf),
      longFrames: r.a.raf.filter((g) => g > 50).length,
      scanLateMs: pct(r.a.scanLate),
      tapToPaintMs: pct(r.a.tap),
    },
    blink: {
      thresholds: thresholds(),
      faceRate: c.results ? round3(c.faceFrames / c.results) : null,
      scoreAvailRate: c.faceFrames ? round3(c.scoreFrames / c.faceFrames) : null,
      min: c.valid ? round3(r.scoreMin) : null,
      max: c.valid ? round3(r.scoreMax) : null,
      histogram20: r.hist,
      holds: { started: r.hold.started, long: r.hold.long, short: r.hold.short, canceled: r.hold.canceled },
      ...r.blink,
    },
    minutes: r.minutes,
    resume: r.resume,
    restart: r.restart,
    memoryMB: performance.memory ? { start: round1(r.memStart / 1048576), end: round1(performance.memory.usedJSHeapSize / 1048576) } : null,
    frames: r.frames.length ? { columns: ["t_ms", "age_ms", "proc_ms", "reason(0有効1エラー2古い3顔なし4スコアなし)"], rows: r.frames } : undefined,
  };
  s.longCheck = longCheck(s);
  return s;
}

function longCheck(s) {
  const m = s.minutes.filter((x) => x.seconds >= 30);
  if (s.durationSec < 25 * 60 || m.length < 10) return null;
  const first = m.slice(0, 5);
  const base = median(first.map((x) => x.procP50).filter((x) => x != null));
  const windows = [[25, 30], [55, 60]]
    .map(([a, b]) => ({ label: `${a}〜${b} 分`, ms: m.filter((x) => x.minute >= a && x.minute < b) }))
    .filter((w) => w.ms.length);
  const parts = [];
  let pass = s.ok && s.stats.counts.stalls1s === 0;
  for (const w of windows) {
    const ivP95 = median(w.ms.map((x) => x.intervalP95).filter((x) => x != null));
    const proc = median(w.ms.map((x) => x.procP50).filter((x) => x != null));
    const ratio = base ? proc / base : null;
    if (!(ivP95 <= 150) || !(ratio <= 1.3)) pass = false;
    parts.push(`${w.label}：間隔95%点 ${fmt(ivP95)}ms・処理中央値 ${fmt(proc, 1)}ms（最初の5分の ${fmt(ratio * 100)}%）`);
  }
  return { pass, baseProcP50: base, text: `最初の5分の処理中央値 ${fmt(base, 1)}ms。${parts.join(" / ")}。止まり ${s.stats.counts.stalls1s} 回` };
}

function userStop(t) {
  const r = run;
  if (!r || r.done) return;
  r.userStopped = true;
  abortSequence = true;
  $("status").textContent = "停止しました";
  $("status").className = "status stopped";
  requestAnimationFrame(() => {
    r.ui.stopToPaintMs = Math.round(performance.now() - t);
    finishRun(r, "user");
  });
}

// ---------- 画面ロック・タブ切替からの復帰 ----------
function suspend(why) {
  const r = run;
  if (!r || r.done || r.suspended) return;
  r.suspended = true;
  r.gen++;
  r.inFlight = null;
  holdCancel(r, "suspend");
  r.resume.events.push({ type: "suspend", why, at: Math.round(performance.now() - r.startup.t0) });
  r.transition = r.transition.then(async () => {
    stopStream(r.stream);
    r.stream = null;
    await r.engine?.close();
    r.engine = null;
  });
}
function resume(why) {
  const r = run;
  if (!r || r.done || !r.suspended || r.userStopped) return;
  r.transition = r.transition.then(async () => {
    if (r.done || !r.suspended) return;
    r.resume.attempts++;
    r.resume.events.push({ type: "resume", why, at: Math.round(performance.now() - r.startup.t0) });
    const t0 = performance.now();
    try {
      await requestWakeLock();
      r.stream = await openCamera();
      const e = r.cfg.mode === "worker" ? new WorkerEngine(paths(false)) : new MainEngine(paths(false));
      await e.init(r.cfg.delegate);
      r.engine = e;
      r.lastValidTs = null;
      r.lastAnyRecv = null;
      r.lastPresented = null;
      r.awaitingFirst = true;
      r.resumeT0 = t0;
      r.suspended = false;
      scheduleFrame(r);
    } catch (err) {
      r.resume.errors.push(String(err?.message || err));
    }
  });
}
document.addEventListener("visibilitychange", () => (document.hidden ? suspend("hidden") : resume("visible")));
window.addEventListener("pagehide", () => suspend("pagehide"));
window.addEventListener("pageshow", (e) => { if (e.persisted) resume("pageshow"); });

// ---------- 合図付きのテスト ----------
async function calibrate(r = run) {
  if (!r || r.done || r.measureStart == null) return alert("先に「開始」して、結果が出始めてから押してください。");
  ensureAudio();
  const collect = async (label, freq) => {
    cue(label);
    beep(freq, 200);
    await sleep(700);
    const arr = [];
    r.sampleSink = arr;
    await sleep(3000);
    r.sampleSink = null;
    return arr;
  };
  const open = await collect("目を開けたまま、画面を見てください（3 秒）", 660);
  const closed = await collect("目を閉じてください（3 秒）", 880);
  beep(440, 300);
  cue("");
  if (r.done) return;
  const med = (a, k) => median(a.map((x) => x[k]));
  if (open.length < 20 || closed.length < 20) {
    r.blink.calibration = { error: `有効なフレームが足りません（開 ${open.length}・閉 ${closed.length}）` };
    return alert(r.blink.calibration.error);
  }
  const O = med(open, "avg");
  const C = med(closed, "avg");
  const cal = {
    O: round3(O), C: round3(C), diff: round3(C - O),
    diffLeft: round3(med(closed, "left") - med(open, "left")),
    diffRight: round3(med(closed, "right") - med(open, "right")),
    closeThr: round3(O + 0.6 * (C - O)),
    openThr: round3(O + 0.25 * (C - O)),
    nOpen: open.length,
    nClosed: closed.length,
  };
  r.blink.calibration = cal;
  if (cal.diff >= 0.29) store.thresholds = { closeThr: cal.closeThr, openThr: cal.openThr, provisional: false };
  saveStore();
  renderThresholds();
}

async function guidedLong(r = run) {
  if (!r || r.done || r.measureStart == null) return alert("先に「開始」して、結果が出始めてから押してください。");
  ensureAudio();
  const g = { prompts: 0, recognized: 0, canceled: 0, results: [] };
  r.blink.guidedLong = g;
  for (let i = 0; i < 10 && !r.done; i++) {
    cue(`${i + 1}/10 目を閉じて`);
    beep(880, 150);
    const tp = performance.now();
    await sleep(1300);
    cue(`${i + 1}/10 目を開けて`);
    beep(440, 150);
    await sleep(2700);
    if (r.done) break;
    const evs = r.events.filter((e) => e.t >= tp && e.t < tp + 3800);
    const ok = evs.some((e) => e.type === "long");
    const cancel = evs.some((e) => e.type === "cancel");
    g.prompts++;
    if (ok) g.recognized++;
    if (cancel) g.canceled++;
    g.results.push(ok ? "認識" : cancel ? "取消" : evs.some((e) => e.type === "short") ? "短すぎ" : "なし");
  }
  cue("");
}

async function normalBlinkTest(r = run) {
  if (!r || r.done || r.measureStart == null) return alert("先に「開始」して、結果が出始めてから押してください。");
  ensureAudio();
  beep(660, 200);
  const t0 = performance.now();
  for (let s = 30; s > 0 && !r.done; s--) {
    cue(`ふつうにまばたきしながら画面を見てください（あと ${s} 秒）`);
    await sleep(1000);
  }
  beep(440, 300);
  cue("");
  const evs = r.events.filter((e) => e.t >= t0);
  r.blink.normalBlink = {
    seconds: Math.round((performance.now() - t0) / 1000),
    falseLong: evs.filter((e) => e.type === "long").length,
    shortBlinks: evs.filter((e) => e.type === "short").length,
    canceled: evs.filter((e) => e.type === "cancel").length,
  };
}

// ---------- 4 通りを順に比べる ----------
async function runComparison() {
  ensureAudio();
  abortSequence = false;
  sequenceActive = true;
  const sec = Number($("cmp-sec").value);
  const withGuided = $("cmp-guided").checked;
  const steps = [["worker", "GPU"], ["main", "GPU"], ["worker", "CPU"], ["main", "CPU"]];
  for (let i = 0; i < steps.length && !abortSequence; i++) {
    const [mode, delegate] = steps[i];
    $("seq").textContent = `比較 ${i + 1}/4：${mode === "worker" ? "Worker" : "画面側"}＋${delegate}`;
    const r = await startRun({ mode, delegate, plannedSec: sec, cold: i === 0 && $("cold").checked, purpose: "比較" });
    if (withGuided && !r.done) {
      while (!r.done && r.measureStart == null) await sleep(200);
      await sleep(3000);
      // しきい値が仮のままだと、開いた目のスコアが高い人で長いまばたきを数えられないので、先に 1 回調整する
      if (!r.done && thresholds().provisional) { await calibrate(r); await sleep(1500); }
      if (!r.done) await guidedLong(r);
    }
    await r.finished;
    await sleep(1500);
  }
  sequenceActive = false;
  setRunningUI(false);
  $("seq").textContent = abortSequence ? "比較を途中で止めました" : "比較が終わりました";
}

// ---------- 表示 ----------
function setRunningUI(on, cfg) {
  document.body.classList.toggle("running", on);
  for (const b of document.querySelectorAll("[data-start]")) b.disabled = on || sequenceActive;
  $("stop").disabled = !on;
  for (const b of document.querySelectorAll("[data-test]")) b.disabled = !on;
  if (on) {
    $("status").textContent = `動作中：${cfg.mode === "worker" ? "Worker" : "画面側"}＋${cfg.delegate}（読み込み中…）`;
    $("status").className = "status running";
  } else if (!$("status").classList.contains("stopped")) {
    $("status").textContent = "止まっています";
    $("status").className = "status";
  }
}

function renderThresholds() {
  const t = thresholds();
  $("thr").textContent = `閉じ ${fmt(t.closeThr, 2)} / 開き ${fmt(t.openThr, 2)}${t.provisional ? "（調整前の仮の値）" : "（調整済み）"}`;
}

function updateLive() {
  const r = run;
  if (!r || r.done) return;
  const elapsed = r.measureStart ? (performance.now() - r.measureStart) / 1000 : 0;
  if (r.measureStart && elapsed >= r.cfg.plannedSec) { finishRun(r, "time"); return; }
  if (r.measureStart && !r.suspended) {
    $("status").textContent = `動作中：${r.cfg.mode === "worker" ? "Worker" : "画面側"}＋${r.cfg.delegate}　${Math.floor(elapsed)} / ${r.cfg.plannedSec} 秒`;
  } else if (r.suspended) $("status").textContent = "一時停止中（画面が隠れたため）";
  const last = (a, n = 150) => pct(a.slice(-n));
  const iv = last(r.a.iv);
  const la = last(r.a.lat);
  const pr = last(r.a.proc);
  const rf = last(r.a.raf, 300);
  const c = r.c;
  const rate = elapsed ? c.valid / elapsed : 0;
  $("live").innerHTML = [
    ["有効な結果", `${fmt(rate, 1)} 回/秒`],
    ["有効フレームの間隔 95%点（直近）", `${fmt(iv.p95)} ms`],
    ["撮影→結果 95%点（直近）", `${fmt(la.p95)} ms`],
    ["1 フレームの処理 中央値 / 95%点", `${fmt(pr.p50, 1)} / ${fmt(pr.p95, 1)} ms`],
    ["描画間隔 95%点", `${fmt(rf.p95)} ms`],
    ["250ms 超 / 300ms 超で捨て / 見張り", `${c.over250} / ${c.stale} / ${c.watchdog}`],
    ["処理中で送れず / 顔なし / エラー", `${c.busySkips} / ${c.noFace} / ${c.errors}`],
    ["保持：開始 / 長い / 短い / 取消", `${r.hold.started} / ${r.hold.long} / ${r.hold.short} / ${Object.values(r.hold.canceled).reduce((a, b) => a + b, 0)}`],
  ].map(([k, v]) => `<div class="kv"><span>${k}</span><b>${v}</b></div>`).join("");
  const L = r.live || {};
  $("bar-left").style.width = `${(L.left ?? 0) * 100}%`;
  $("bar-right").style.width = `${(L.right ?? 0) * 100}%`;
  $("score-text").textContent = L.avg == null ? (r.measureStart ? "顔なし・無効" : "準備中") : `左 ${fmt(L.left, 2)}　右 ${fmt(L.right, 2)}　平均 ${fmt(L.avg, 2)}`;
  $("hold-state").textContent = { arm: "開眼（待機）", closed: "閉眼中（保持）", waitOpen: "開眼待ち" }[r.hold.state];
}
setInterval(updateLive, 500);

const statusClass = { 合格: "pass", 不合格: "fail", 未測定: "none", 記録: "none" };
function esc(s) {
  return String(s ?? "").replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch]);
}

function renderResults(selectedId) {
  const runs = store.runs;
  $("runs-count").textContent = runs.length;
  $("runs").innerHTML = runs.length
    ? `<table><thead><tr><th>#</th><th>組み合わせ</th><th>秒</th><th>結果</th><th>起動→最初</th><th>間隔95%</th><th>撮影→結果95%</th><th>処理 中央/95%</th><th>描画95%</th><th>長いまばたき</th></tr></thead><tbody>${runs
      .map((s, i) => {
        const st = s.stats;
        const g = s.blink?.guidedLong;
        return `<tr data-id="${esc(s.id)}" class="${s.id === selectedId ? "sel" : ""}"><td>${i + 1}</td><td>${esc(s.label)}${s.startup?.cold ? "（初回）" : ""}</td><td>${s.durationSec}</td><td class="${s.ok ? "pass" : "fail"}">${s.ok ? "成功" : "失敗"}</td><td>${fmt((s.startup?.firstResultTotalMs ?? NaN) / 1000, 1)}s</td><td>${fmt(st.validIntervalMs?.p95)}</td><td>${fmt(st.latencyMs?.p95)}</td><td>${fmt(st.procMs?.p50, 1)}/${fmt(st.procMs?.p95, 1)}</td><td>${fmt(s.ui?.rafGapMs?.p95)}</td><td>${g ? `${g.recognized}/${g.prompts}` : "—"}</td></tr>`;
      })
      .join("")}</tbody></table>`
    : "<p>まだありません。</p>";
  for (const tr of $("runs").querySelectorAll("tr[data-id]")) tr.addEventListener("click", () => renderResults(tr.dataset.id));
  const sel = runs.find((s) => s.id === selectedId) || runs[runs.length - 1];
  if (!sel) { $("eval").innerHTML = ""; return; }
  const rows = evaluate(sel);
  $("eval-title").textContent = `${sel.label}（${new Date(sel.startedAt).toLocaleString("ja-JP")}・${sel.durationSec} 秒）`;
  $("eval").innerHTML = `<table><thead><tr><th>項目</th><th>条件</th><th>結果</th><th>判定</th></tr></thead><tbody>${rows
    .map((x) => `<tr><td>${esc(x.group)}</td><td><span class="src ${x.source === "仮" ? "tmp" : ""}">${x.source}</span>${esc(x.text)}</td><td>${esc(x.value)}</td><td class="${statusClass[x.status]}">${x.status}</td></tr>`)
    .join("")}</tbody></table>${sel.error ? `<p class="fail">エラー：${esc(sel.error)}</p>` : ""}${sel.minutes?.length > 1 ? renderMinutes(sel) : ""}`;
}

function renderMinutes(s) {
  return `<h4>1 分ごとの変化</h4><table><thead><tr><th>分</th><th>有効/秒</th><th>間隔95%</th><th>撮影→結果95%</th><th>処理 中央/95%</th><th>描画95%</th><th>250ms超</th><th>捨て</th></tr></thead><tbody>${s.minutes
    .map((m) => `<tr><td>${m.minute}</td><td>${fmt(m.validRate, 1)}</td><td>${fmt(m.intervalP95)}</td><td>${fmt(m.latencyP95)}</td><td>${fmt(m.procP50, 1)}/${fmt(m.procP95, 1)}</td><td>${fmt(m.rafP95)}</td><td>${m.over250}</td><td>${m.stale}</td></tr>`)
    .join("")}</tbody></table>`;
}

function renderCriteria() {
  $("criteria").innerHTML = `<table><thead><tr><th>項目</th><th>根拠</th><th>合格条件</th></tr></thead><tbody>${CRITERIA.map(
    (c) => `<tr><td>${esc(c.group)}</td><td><span class="src ${c.source === "仮" ? "tmp" : ""}">${c.source}</span></td><td>${esc(c.text)}</td></tr>`,
  ).join("")}</tbody></table>`;
}

// ---------- 結果を渡す ----------
function exportData() {
  return {
    schema: "mabatalk-blink-pr05/v1",
    exportedAt: new Date().toISOString(),
    pageVersion: PAGE_VERSION,
    versions: VERSIONS,
    limits: LIMITS,
    criteria: CRITERIA,
    device: deviceInfo(),
    manual: readManual(),
    thresholds: thresholds(),
    runs: store.runs.map((s) => ({ ...s, evaluation: evaluate(s) })),
    notes: [
      "映像・画像・フレームごとのスコアは含まない。frames は時間の数字と有効/無効の理由だけ。",
      "端末の型番・OS の版は Safari から取れないので manual に手入力。",
    ],
  };
}
const fileName = () => `blink-pr05-${new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-")}.json`;
async function copyJson() {
  const text = JSON.stringify(exportData(), null, 1);
  try {
    await navigator.clipboard.writeText(text);
    flash("コピーしました");
  } catch {
    const ta = $("json-out");
    ta.hidden = false;
    ta.value = text;
    ta.select();
    flash(document.execCommand("copy") ? "コピーしました" : "下の枠を全選択してコピーしてください");
  }
}
function downloadJson() {
  const blob = new Blob([JSON.stringify(exportData(), null, 1)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = fileName();
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}
async function shareJson() {
  const file = new File([JSON.stringify(exportData(), null, 1)], fileName(), { type: "application/json" });
  if (navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ files: [file], title: "まばたき計測の結果" }); } catch { /* 取り消し */ }
  } else flash("この端末では共有が使えません。「保存」か「コピー」を使ってください");
}
function flash(msg) {
  $("flash").textContent = msg;
  setTimeout(() => { $("flash").textContent = ""; }, 4000);
}

// ---------- ボタン ----------
function selectedCfg(plannedSec, purpose) {
  return {
    mode: $("mode").value,
    delegate: $("delegate").value,
    plannedSec,
    cold: $("cold").checked,
    purpose,
  };
}
$("start").addEventListener("click", () => { ensureAudio(); $("status").classList.remove("stopped"); startRun(selectedCfg(Number($("dur").value), "単独")); });
$("compare").addEventListener("click", () => { $("status").classList.remove("stopped"); runComparison(); });
$("stop").addEventListener("pointerdown", (e) => {
  const t = e.timeStamp > 0 && e.timeStamp <= performance.now() + 5 ? e.timeStamp : performance.now();
  userStop(t);
});
$("tap").addEventListener("pointerdown", (e) => {
  const t = e.timeStamp > 0 && e.timeStamp <= performance.now() + 5 ? e.timeStamp : performance.now();
  $("tap").classList.toggle("alt");
  const r = run;
  requestAnimationFrame(() => { if (r && !r.done) r.a.tap.push(performance.now() - t); });
});
$("calib").addEventListener("click", () => calibrate());
$("guided").addEventListener("click", () => guidedLong());
$("normal").addEventListener("click", () => normalBlinkTest());
$("copy").addEventListener("click", copyJson);
$("download").addEventListener("click", downloadJson);
$("share").addEventListener("click", shareJson);
$("clear").addEventListener("click", () => {
  if (!confirm("この端末に残っている計測結果と調整値を消しますか？")) return;
  store.runs = [];
  store.thresholds = null;
  saveStore();
  renderResults();
  renderThresholds();
});
for (const k of MANUAL_FIELDS) {
  const el = $(`m-${k}`);
  if (store.manual?.[k] != null) el.value = store.manual[k];
  el.addEventListener("change", () => { store.manual = readManual(); saveStore(); });
}

// ---------- 最初の表示 ----------
(function init() {
  const d = deviceInfo();
  $("env").textContent = `Safari ${d.safariVersion || "?"}・${d.looksLikeIPad ? "iPad と思われる" : "iPad 以外"}・GPU: ${d.webgl?.renderer || "?"}・コア ${d.hardwareConcurrency ?? "?"}・requestVideoFrameCallback ${d.features.requestVideoFrameCallback ? "あり" : "なし"}・Wake Lock ${d.features.wakeLock ? "あり" : "なし"}${SOURCE !== "camera" ? `・入力：${SOURCE}（テスト用）` : ""}`;
  if (!window.isSecureContext) $("insecure").hidden = false;
  if (!$("m-launch").value) $("m-launch").value = d.standalone ? "ホーム画面から" : "Safari のタブ";
  renderThresholds();
  renderCriteria();
  renderResults();
  setRunningUI(false);
  window.__blinkMeasure = { exportData, store, get run() { return run; }, get audioState() { return audioCtx?.state ?? null; } }; // Mac の自動確認用
})();
