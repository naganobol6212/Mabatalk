// module Worker（new Worker(url, { type: "module" })）で動かす。useModule: true。
// GPU→CPU の切り替えは同じ Worker で作り直さず、Worker ごと作り直す（設計・Codex 中の指摘）。
import { landmarkerOptions, summarize, resourceEntries } from "./face_common.js";

let landmarker = null;

self.onmessage = async (e) => {
  const m = e.data;
  if (m.type === "init") {
    const t0 = performance.now();
    try {
      const vision = await import(m.bundleUrl);
      const t1 = performance.now();
      const fileset = await vision.FilesetResolver.forVisionTasks(m.wasmBase, true);
      const t2 = performance.now();
      const canvas = new OffscreenCanvas(1, 1);
      landmarker = await vision.FaceLandmarker.createFromOptions(
        fileset,
        landmarkerOptions(m.modelUrl, m.delegate, canvas),
      );
      const t3 = performance.now();
      self.postMessage({
        type: "ready",
        timings: { importMs: t1 - t0, filesetMs: t2 - t1, createMs: t3 - t2 },
        resources: resourceEntries(0),
      });
    } catch (err) {
      self.postMessage({ type: "initError", error: String(err?.message || err) });
    }
    return;
  }
  if (m.type === "frame") {
    const t = performance.now();
    try {
      const r = landmarker.detectForVideo(m.bitmap, m.ts);
      const procMs = performance.now() - t;
      self.postMessage({ type: "result", seq: m.seq, gen: m.gen, procMs, ...summarize(r) });
    } catch (err) {
      self.postMessage({ type: "result", seq: m.seq, gen: m.gen, procMs: performance.now() - t, error: String(err?.message || err) });
    } finally {
      m.bitmap.close();
    }
    return;
  }
  if (m.type === "ping") {
    self.postMessage({ type: "pong", id: m.id });
    return;
  }
  if (m.type === "close") {
    try { landmarker?.close(); } catch { /* 終了処理の失敗は無視 */ }
    landmarker = null;
    self.postMessage({ type: "closed" });
  }
};
