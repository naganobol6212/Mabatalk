import { test } from "node:test"
import assert from "node:assert/strict"
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import {
  MEDIAPIPE_VERSION,
  MODEL_FILE,
  PACKAGE_DIR,
  WASM_DEST_DIR,
  WASM_FILES,
  copyVerified,
  run,
  verifyFile
} from "../../script/copy_mediapipe_wasm.mjs"

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

function sha256(content) {
  return createHash("sha256").update(content).digest("hex")
}

function withTmpDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "mediapipe-copy-"))
  try {
    return fn(dir)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

function writeFile(path, content) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, content)
}

// 本物の 14MB を使わずに run() を試すため、期待値を小さな偽物に合わせた環境を作る
function fakeRoot(dir, { version = MEDIAPIPE_VERSION, wasmContent = (name) => `wasm:${name}`, modelContent = "model" } = {}) {
  writeFile(join(dir, PACKAGE_DIR, "package.json"), JSON.stringify({ version }))
  for (const file of WASM_FILES) writeFile(join(dir, PACKAGE_DIR, "wasm", file.name), wasmContent(file.name))
  writeFile(join(dir, MODEL_FILE.path), modelContent)
}

test("版は 1.2.3 に固定し、写す先の URL にも版を入れる", () => {
  assert.equal(MEDIAPIPE_VERSION, "1.2.3")
  assert.equal(WASM_DEST_DIR, "public/mediapipe/tasks-vision/1.2.3/wasm")
  assert.deepEqual(WASM_FILES.map((file) => file.name), [
    "vision_wasm_module_internal.js",
    "vision_wasm_module_internal.wasm"
  ])
})

test("package.json は版を固定している（^ や ~ を付けない）", () => {
  const packageJson = JSON.parse(readFileSync(join(repoRoot, "package.json"), "utf8"))
  assert.equal(packageJson.dependencies["@mediapipe/tasks-vision"], MEDIAPIPE_VERSION)
  assert.match(packageJson.scripts.build, /^node script\/copy_mediapipe_wasm\.mjs && esbuild /)
})

test("写す先は git に入れない", () => {
  const gitignore = readFileSync(join(repoRoot, ".gitignore"), "utf8").split("\n")
  assert.ok(gitignore.includes("/public/mediapipe/tasks-vision/"))
})

test("NOTICE に書いた大きさとハッシュは、ビルドで確かめる値と同じ", () => {
  const notice = readFileSync(join(repoRoot, "public/mediapipe/NOTICE"), "utf8")
  for (const { size, sha256: hash } of [ ...WASM_FILES, MODEL_FILE ]) {
    assert.ok(notice.includes(`SHA-256 ${hash}`), hash)
    assert.ok(notice.includes(`${size.toLocaleString("en-US")} bytes`), String(size))
  }
})

test("git に入っているモデルは、記録した大きさと SHA-256 のとおり", () => {
  assert.doesNotThrow(() => verifyFile(join(repoRoot, MODEL_FILE.path), MODEL_FILE))
})

test("verifyFile: 無い・大きさが違う・ハッシュが違う時は、理由を付けて失敗する", () => {
  withTmpDir((dir) => {
    const path = join(dir, "a.bin")
    const expected = { size: 5, sha256: sha256("hello") }

    assert.throws(() => verifyFile(path, expected), /がありません/)

    writeFileSync(path, "hello!")
    assert.throws(() => verifyFile(path, expected), /大きさが違います（期待 5 バイト、実際 6 バイト）/)

    writeFileSync(path, "HELLO")
    assert.throws(() => verifyFile(path, expected), /SHA-256 が違います/)

    writeFileSync(path, "hello")
    assert.doesNotThrow(() => verifyFile(path, expected))
  })
})

test("copyVerified: 写して確かめる。写し済みで正しければ写し直さない", () => {
  withTmpDir((dir) => {
    const src = join(dir, "src", "a.wasm")
    const dest = join(dir, "dest", "deep", "a.wasm")
    const expected = { size: 4, sha256: sha256("wasm") }
    writeFile(src, "wasm")

    assert.equal(copyVerified(src, dest, expected), "copied")
    assert.equal(readFileSync(dest, "utf8"), "wasm")
    assert.equal(copyVerified(src, dest, expected), "skipped")
    assert.deepEqual(readdirSync(dirname(dest)), [ "a.wasm" ])
  })
})

test("copyVerified: 写し先が壊れていたら写し直す", () => {
  withTmpDir((dir) => {
    const src = join(dir, "a.wasm")
    const dest = join(dir, "out", "a.wasm")
    const expected = { size: 4, sha256: sha256("wasm") }
    writeFile(src, "wasm")
    writeFile(dest, "old!")

    assert.equal(copyVerified(src, dest, expected), "copied")
    assert.equal(readFileSync(dest, "utf8"), "wasm")
  })
})

test("copyVerified: 元が期待と違えば失敗し、写し先に何も残さない（古い写しも消す）", () => {
  withTmpDir((dir) => {
    const src = join(dir, "a.wasm")
    const dest = join(dir, "out", "a.wasm")
    const expected = { size: 4, sha256: sha256("wasm") }
    writeFile(src, "WASM")

    assert.throws(() => copyVerified(src, dest, expected), /SHA-256 が違います/)
    assert.equal(existsSync(dest), false)
    assert.equal(existsSync(`${dest}.tmp`), false)
  })
})

test("run: 入っている版が 1.2.3 でなければ失敗する", () => {
  withTmpDir((dir) => {
    fakeRoot(dir, { version: "1.2.4" })
    assert.throws(() => run(dir), /版が違います（期待 1\.2\.3、実際 1\.2\.4）/)
  })
})

test("run: yarn install 前（パッケージが無い）なら失敗する", () => {
  withTmpDir((dir) => {
    assert.throws(() => run(dir), /yarn install/)
  })
})

test("run: WASM が期待と違えば失敗し、public に写さない", () => {
  withTmpDir((dir) => {
    fakeRoot(dir)
    assert.throws(() => run(dir), /vision_wasm_module_internal\.js の大きさが違います/)
    assert.equal(existsSync(join(dir, WASM_DEST_DIR, "vision_wasm_module_internal.js")), false)
  })
})

test("run: 本物の node_modules なら写せて、2 回目は写し直さない（yarn install 済みの時だけ）", { skip: !existsSync(join(repoRoot, PACKAGE_DIR, "package.json")) }, () => {
  withTmpDir((dir) => {
    for (const file of WASM_FILES) {
      writeFile(join(dir, PACKAGE_DIR, "wasm", file.name), readFileSync(join(repoRoot, PACKAGE_DIR, "wasm", file.name)))
    }
    writeFile(join(dir, PACKAGE_DIR, "package.json"), readFileSync(join(repoRoot, PACKAGE_DIR, "package.json")))
    writeFile(join(dir, MODEL_FILE.path), readFileSync(join(repoRoot, MODEL_FILE.path)))

    assert.deepEqual(run(dir).map(({ result }) => result), [ "copied", "copied" ])
    assert.deepEqual(run(dir).map(({ result }) => result), [ "skipped", "skipped" ])
  })
})

test("run: モデルが壊れていれば失敗する", { skip: !existsSync(join(repoRoot, PACKAGE_DIR, "package.json")) }, () => {
  withTmpDir((dir) => {
    for (const file of WASM_FILES) {
      writeFile(join(dir, PACKAGE_DIR, "wasm", file.name), readFileSync(join(repoRoot, PACKAGE_DIR, "wasm", file.name)))
    }
    writeFile(join(dir, PACKAGE_DIR, "package.json"), readFileSync(join(repoRoot, PACKAGE_DIR, "package.json")))
    writeFile(join(dir, MODEL_FILE.path), "not a model")

    assert.throws(() => run(dir), /face_landmarker-float16-1\.task の大きさが違います/)
  })
})
