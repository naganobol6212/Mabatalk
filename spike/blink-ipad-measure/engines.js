// 2 つの版を同じ形で呼べるようにする。
//   WorkerEngine : module Worker ＋ useModule: true ＋ vision_wasm_module_internal.*
//   MainEngine   : メインスレッド ＋ useModule: false ＋ vision_wasm_internal.*（script 要素で読む経路）
// detect(frame) はどちらも Promise を返す。frame = { video, ts, seq, gen }
import { landmarkerOptions, summarize, resourceEntries } from "./face_common.js";

export class WorkerEngine {
  constructor(paths) {
    this.paths = paths;
    this.kind = "worker";
    this.worker = null;
    this.pending = new Map();
    this.onFatal = null;
  }

  init(delegate) {
    return new Promise((resolve, reject) => {
      const w = new Worker(new URL("./face_worker.js", import.meta.url), { type: "module" });
      this.worker = w;
      w.onerror = (ev) => {
        const msg = `Worker error: ${ev.message || "unknown"}`;
        reject(new Error(msg));
        this.onFatal?.(msg);
      };
      w.onmessage = (e) => {
        const m = e.data;
        if (m.type === "ready") resolve({ timings: m.timings, resources: m.resources });
        else if (m.type === "initError") reject(new Error(m.error));
        else if (m.type === "result") {
          const p = this.pending.get(m.seq);
          if (p) {
            this.pending.delete(m.seq);
            p.resolve({ ...m, grabMs: p.grabMs });
          }
        } else if (m.type === "pong") {
          this._pong?.(m.id);
        }
      };
      w.postMessage({
        type: "init",
        bundleUrl: this.paths.bundleUrl,
        wasmBase: this.paths.wasmBase,
        modelUrl: this.paths.modelUrl,
        delegate,
      });
    });
  }

  async detect(frame) {
    const g0 = performance.now();
    const bitmap = await createImageBitmap(frame.video);
    const grabMs = performance.now() - g0;
    return new Promise((resolve) => {
      this.pending.set(frame.seq, { resolve, grabMs });
      this.worker.postMessage({ type: "frame", seq: frame.seq, gen: frame.gen, ts: frame.ts, bitmap }, [bitmap]);
    });
  }

  // terminate したあと、本当に返事が来ないかを確かめる（「Worker が実際に止まる」の確認）。
  async close() {
    const w = this.worker;
    if (!w) return { stopped: true };
    try { w.postMessage({ type: "close" }); } catch { /* 無視 */ }
    w.terminate();
    this.worker = null;
    this.pending.clear();
    const gotPong = await new Promise((resolve) => {
      const t = setTimeout(() => resolve(false), 300);
      this._pong = () => { clearTimeout(t); resolve(true); };
      try { w.postMessage({ type: "ping", id: 1 }); } catch { clearTimeout(t); resolve(false); }
    });
    this._pong = null;
    return { stopped: !gotPong };
  }
}

export class MainEngine {
  constructor(paths) {
    this.paths = paths;
    this.kind = "main";
    this.landmarker = null;
    this.onFatal = null;
  }

  async init(delegate) {
    const since = performance.now();
    const t0 = performance.now();
    const vision = await import(this.paths.bundleUrl);
    const t1 = performance.now();
    const fileset = await vision.FilesetResolver.forVisionTasks(this.paths.wasmBase, false);
    const t2 = performance.now();
    this.landmarker = await vision.FaceLandmarker.createFromOptions(
      fileset,
      landmarkerOptions(this.paths.modelUrl, delegate, null),
    );
    const t3 = performance.now();
    return {
      timings: { importMs: t1 - t0, filesetMs: t2 - t1, createMs: t3 - t2 },
      resources: resourceEntries(since - 50),
    };
  }

  detect(frame) {
    const t = performance.now();
    try {
      const r = this.landmarker.detectForVideo(frame.video, frame.ts);
      return Promise.resolve({ seq: frame.seq, gen: frame.gen, procMs: performance.now() - t, grabMs: 0, ...summarize(r) });
    } catch (err) {
      return Promise.resolve({ seq: frame.seq, gen: frame.gen, procMs: performance.now() - t, grabMs: 0, error: String(err?.message || err) });
    }
  }

  async close() {
    try { this.landmarker?.close(); } catch { /* 無視 */ }
    this.landmarker = null;
    return { stopped: true };
  }
}
