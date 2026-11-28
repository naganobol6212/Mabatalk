// MediaPipe（まばたき入力で顔を読むライブラリ）の WASM を、node_modules から public に写す。
// `yarn build` の最初に走る（CI と Render の assets:precompile も yarn build を呼ぶので、同じ処理が通る）。
//
// - 版は 1.2.3 に固定する。URL に版を入れ、同じ URL の中身を上書きしない（長期キャッシュのため）
// - 写す前と写した後に、大きさと SHA-256 を下の値と比べる。1 つでも違えばビルドを失敗させる
// - 写した先（public/mediapipe/tasks-vision/）は git に入れない。モデルは git に入れ、ここで中身を確かめるだけ
//
// 版を上げる時は、package.json・yarn.lock・下の MEDIAPIPE_VERSION と大きさ・ハッシュ・
// public/mediapipe/NOTICE をまとめて変える（どれか 1 つだけ変えるとビルドが止まる）。
import { createHash } from "node:crypto"
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, statSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

export const MEDIAPIPE_VERSION = "1.2.3"

// module Worker（type: "module"）＋ useModule: true で読む組（設計書 11 章）
export const WASM_FILES = [
  {
    name: "vision_wasm_module_internal.js",
    size: 336_662,
    sha256: "d29996249490361715c769c6a49b43ad47e6ac9a28a8e8bce8d02b238e897851"
  },
  {
    name: "vision_wasm_module_internal.wasm",
    size: 14_665_738,
    sha256: "a269e84b12aefc93c9d6a4d62b01f41e5434a9fa941533bb8e75b1e3d1669e46"
  }
]

// face_landmarker/float16/1（公式: storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task）
export const MODEL_FILE = {
  path: "public/mediapipe/models/face_landmarker-float16-1.task",
  size: 3_758_596,
  sha256: "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"
}

export const PACKAGE_DIR = "node_modules/@mediapipe/tasks-vision"
export const WASM_DEST_DIR = `public/mediapipe/tasks-vision/${MEDIAPIPE_VERSION}/wasm`

// ファイルの大きさと SHA-256 が期待どおりか確かめる。違えば理由を書いて例外を投げる
export function verifyFile(path, { size, sha256 }) {
  if (!existsSync(path)) throw new Error(`${path} がありません`)

  const actualSize = statSync(path).size
  if (actualSize !== size) {
    throw new Error(`${path} の大きさが違います（期待 ${size} バイト、実際 ${actualSize} バイト）`)
  }

  const actualSha256 = createHash("sha256").update(readFileSync(path)).digest("hex")
  if (actualSha256 !== sha256) {
    throw new Error(`${path} の SHA-256 が違います（期待 ${sha256}、実際 ${actualSha256}）`)
  }
}

// 写す元を確かめ、一時ファイルに写して確かめてから本来の名前にする。
// 写した先が既に正しければ何もしない。途中で失敗したら、壊れたファイルを残さない
export function copyVerified(src, dest, expected) {
  verifyFile(src, expected)

  if (existsSync(dest)) {
    try {
      verifyFile(dest, expected)
      return "skipped"
    } catch {
      rmSync(dest, { force: true })
    }
  }

  mkdirSync(dirname(dest), { recursive: true })
  const tmp = `${dest}.tmp`
  try {
    copyFileSync(src, tmp)
    verifyFile(tmp, expected)
    renameSync(tmp, dest)
  } finally {
    rmSync(tmp, { force: true })
  }
  return "copied"
}

export function checkPackageVersion(root) {
  const packageJson = join(root, PACKAGE_DIR, "package.json")
  if (!existsSync(packageJson)) {
    throw new Error(`${packageJson} がありません（yarn install を先に実行してください）`)
  }
  const { version } = JSON.parse(readFileSync(packageJson, "utf8"))
  if (version !== MEDIAPIPE_VERSION) {
    throw new Error(`@mediapipe/tasks-vision の版が違います（期待 ${MEDIAPIPE_VERSION}、実際 ${version}）`)
  }
}

export function run(root) {
  checkPackageVersion(root)

  const results = WASM_FILES.map((file) => {
    const src = join(root, PACKAGE_DIR, "wasm", file.name)
    const dest = join(root, WASM_DEST_DIR, file.name)
    return { name: file.name, result: copyVerified(src, dest, file) }
  })

  verifyFile(join(root, MODEL_FILE.path), MODEL_FILE)
  return results
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), "..")
  try {
    for (const { name, result } of run(root)) {
      console.log(`mediapipe: ${name} ${result === "copied" ? "を写しました" : "は写し済み（確認済み）"}`)
    }
    console.log("mediapipe: モデルの大きさと SHA-256 を確認しました")
  } catch (error) {
    console.error(`mediapipe: ${error.message}`)
    process.exit(1)
  }
}
