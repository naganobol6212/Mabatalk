// 計測ページを 127.0.0.1 だけで配る小さな静的サーバー（依存なし）。
// iPad からは cloudflared のトンネル（HTTPS）経由で開く。Mac の Chrome なら http://localhost でもカメラが使える。
import { createServer } from "node:http";
import { createReadStream, statSync } from "node:fs";
import { extname, join, normalize, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 8787);
const TYPES = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm", ".task": "application/octet-stream", ".json": "application/json", ".jpg": "image/jpeg",
  ".map": "application/json",
};
const ALLOWED = /^\/(index\.html|app\.js|engines\.js|face_common\.js|face_worker\.js|criteria\.js|vendor\/.+)$/;

createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (p === "/") p = "/index.html";
  // /vendor-bust/<何でも>/... は「キャッシュなし」の計測用。中身は vendor/ と同じ
  p = p.replace(/^\/vendor-bust\/[^/]+\//, "/vendor/");
  const headers = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Robots-Tag": "noindex, nofollow",
  };
  // Mac 確認用のテスト画像はトンネル（外）からは出さない
  const viaTunnel = !!req.headers["cf-connecting-ip"];
  if (!ALLOWED.test(p) || p.includes("..") || (viaTunnel && p.startsWith("/vendor/test/"))) { res.writeHead(404, headers); res.end("not found"); return; }
  const file = normalize(join(root, p));
  let st;
  try { st = statSync(file); } catch { res.writeHead(404, headers); res.end("not found"); return; }
  if (!st.isFile()) { res.writeHead(404, headers); res.end("not found"); return; }
  headers["Content-Type"] = TYPES[extname(file)] || "application/octet-stream";
  headers["Content-Length"] = st.size;
  // 版付きの vendor は本番と同じく長くキャッシュ。ページの JS は毎回確かめる
  headers["Cache-Control"] = p.startsWith("/vendor/") ? "public, max-age=86400, immutable" : "no-cache";
  res.writeHead(200, headers);
  if (req.method === "HEAD") { res.end(); return; }
  createReadStream(file).pipe(res);
}).listen(port, "127.0.0.1", () => console.log(`http://localhost:${port}/`));
