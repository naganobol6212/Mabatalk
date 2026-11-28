// Mac の Chrome（ヘッドレス）で計測ページを動かし、2 つの版で数字が出るかを確かめる。
//   node tools/mac-check.mjs [source=image|camera] [秒]
// 先に `node server.mjs` を動かしておく。カメラは Chrome の偽カメラ、image は公開のテスト画像（顔あり）。
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const source = process.argv[2] || "image";
const sec = process.argv[3] || "20";
const out = process.env.OUT || tmpdir();
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const port = 9333;
const profile = mkdtempSync(join(tmpdir(), "blink-chrome-"));
const chrome = spawn(CHROME, [
  "--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  "--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream", "--autoplay-policy=no-user-gesture-required",
  "--no-first-run", "--window-size=1200,1800", "about:blank",
], { stdio: "ignore" });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function json(path, method = "GET") {
  for (let i = 0; i < 50; i++) {
    try { return await (await fetch(`http://127.0.0.1:${port}${path}`, { method })).json(); } catch { await sleep(200); }
  }
  throw new Error("Chrome に繋がらない");
}

const target = await json(`/json/new?${encodeURIComponent(`${process.env.BASE || "http://localhost:8787"}/?source=${source}`)}`, "PUT");
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r, { once: true }));
let id = 0;
const waiting = new Map();
const logs = [];
ws.addEventListener("message", (e) => {
  const m = JSON.parse(e.data);
  if (m.id && waiting.has(m.id)) { waiting.get(m.id)(m); waiting.delete(m.id); }
  if (m.method === "Runtime.consoleAPICalled") logs.push(m.params.args.map((a) => a.value ?? a.description).join(" "));
  if (m.method === "Runtime.exceptionThrown") logs.push(`EXC ${m.params.exceptionDetails.exception?.description}`);
});
const send = (method, params = {}) => new Promise((r) => { const i = ++id; waiting.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const evaluate = async (expr) => (await send("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true })).result?.result?.value;
async function click(sel) {
  const box = await evaluate(`(() => { const r = document.querySelector(${JSON.stringify(sel)}).getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
  for (const type of ["mousePressed", "mouseReleased"]) await send("Input.dispatchMouseEvent", { type, x: box.x, y: box.y, button: "left", clickCount: 1 });
}

await send("Runtime.enable");
for (let i = 0; i < 60; i++) { if (await evaluate(`document.getElementById("env")?.textContent`)) break; await sleep(500); }
console.log("env:", await evaluate(`document.getElementById("env").textContent`));

// 1) 4 通りの比較（合図テストなし）
await evaluate(`document.getElementById("cmp-sec").innerHTML += '<option value="${sec}">${sec}</option>'; document.getElementById("cmp-sec").value = "${sec}"; document.getElementById("cmp-guided").checked = false; document.getElementById("cold").checked = ${process.env.COLD ? "true" : "false"};`);
await click("#compare");
const t0 = Date.now();
while (Date.now() - t0 < 4 * (Number(sec) + 40) * 1000) {
  const s = await evaluate(`document.getElementById("seq").textContent + " | " + document.getElementById("status").textContent`);
  if (/比較が終わりました|止めました/.test(s)) break;
  await sleep(2000);
}

// 2) 単独で開始→タップ反応→停止ボタン（停止の反映と track/Worker 停止）→もう一度開始（再起動）
for (let k = 0; k < 2; k++) {
  await evaluate(`document.getElementById("mode").value = "worker"; document.getElementById("delegate").value = "GPU"; document.getElementById("dur").value = "60";`);
  await click("#start");
  for (let i = 0; i < 40; i++) { if (await evaluate(`!!window.__blinkMeasure.run?.measureStart`)) break; await sleep(500); }
  await sleep(4000);
  for (let i = 0; i < 5; i++) { await click("#tap"); await sleep(300); }
  await click("#stop");
  await sleep(2000);
}

// 3) extra：合図付きテストと「画面が隠れた→戻った」の流れ（テスト画像ではまばたきしないので、動くかだけ見る）
if (process.argv[4] === "extra") {
  await evaluate(`document.getElementById("mode").value = "main"; document.getElementById("delegate").value = "GPU"; document.getElementById("dur").value = "300";`);
  await click("#start");
  for (let i = 0; i < 40; i++) { if (await evaluate(`!!window.__blinkMeasure.run?.measureStart`)) break; await sleep(500); }
  await sleep(2000);
  await evaluate(`window.alert = (m) => console.log("alert:", m)`);
  await click("#calib");
  await sleep(9000);
  // visibilitychange を擬似的に起こす（ヘッドレスでは本物のタブ切替ができないため）
  await evaluate(`Object.defineProperty(document, "hidden", { configurable: true, get: () => true }); document.dispatchEvent(new Event("visibilitychange"));`);
  await sleep(1500);
  await evaluate(`Object.defineProperty(document, "hidden", { configurable: true, get: () => false }); document.dispatchEvent(new Event("visibilitychange"));`);
  await sleep(4000);
  await click("#guided");
  await sleep(42000);
  await click("#normal");
  await sleep(33000);
  await click("#stop");
  await sleep(2000);
}

const shot = await send("Page.captureScreenshot", { format: "png", captureBeyondViewport: true });
writeFileSync(join(out, `mac-check-${source}.png`), Buffer.from(shot.result.data, "base64"));
const data = await evaluate(`JSON.stringify(window.__blinkMeasure.exportData())`);
writeFileSync(join(out, `mac-check-${source}.json`), data);
const d = JSON.parse(data);
for (const r of d.runs) {
  const st = r.stats;
  console.log(`${r.label.padEnd(12)} ok=${r.ok} ${r.durationSec}s 起動→最初=${r.startup.firstResultTotalMs}ms create=${r.startup.createMs}ms 有効=${st.validRate}/s 間隔p95=${st.validIntervalMs.p95} 遅れp95=${st.latencyMs.p95} 処理p50/p95=${st.procMs.p50}/${st.procMs.p95} 描画p95=${r.ui.rafGapMs.p95} 顔率=${r.blink.faceRate} スコア=${r.blink.min}-${r.blink.max} 停止=${r.ui.stopToPaintMs ?? "-"}ms track=${r.ui.tracksEnded} engine=${r.ui.engineStopped} err=${r.error || ""}`);
  console.log("   " + r.evaluation.map((e) => `${e.id}:${e.status}`).join(" "));
}
if (logs.length) console.log("console:", logs.slice(0, 20).join("\n  "));
ws.close();
chrome.kill();
