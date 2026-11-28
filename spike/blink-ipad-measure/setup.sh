#!/usr/bin/env bash
# MediaPipe tasks-vision 1.2.3 とモデルを取ってきて vendor/ に置く。版とハッシュが違えば止まる。
set -euo pipefail
cd "$(dirname "$0")"
V=vendor
TV_SHA1=269f616515f3e244c9812e7738aa71551cbd9822          # npm の dist.shasum（1.2.3）
MODEL_SHA256=64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff
MODEL_URL=https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
TEST_IMG_URL=https://storage.googleapis.com/mediapipe-assets/portrait.jpg   # Mac 確認用の公開テスト画像

mkdir -p "$V/models" "$V/test"
if [ ! -f "$V/tasks-vision/wasm/vision_wasm_module_internal.wasm" ]; then
  tmp=$(mktemp -d)
  curl -sSfL -o "$tmp/tv.tgz" https://registry.npmjs.org/@mediapipe/tasks-vision/-/tasks-vision-1.2.3.tgz
  echo "$TV_SHA1  $tmp/tv.tgz" | shasum -a 1 -c -
  tar -xzf "$tmp/tv.tgz" -C "$tmp"
  rm -rf "$V/tasks-vision" && mv "$tmp/package" "$V/tasks-vision"
  rm -rf "$tmp"
fi
[ "$(wc -c < "$V/tasks-vision/wasm/vision_wasm_module_internal.wasm" | tr -d ' ')" = "14665738" ] || { echo "WASM の大きさが違います"; exit 1; }
if [ ! -f "$V/models/face_landmarker.task" ]; then
  curl -sSfL -o "$V/models/face_landmarker.task" "$MODEL_URL"
fi
echo "$MODEL_SHA256  $V/models/face_landmarker.task" | shasum -a 256 -c -
if [ ! -f "$V/test/face.jpg" ]; then
  curl -sSfL -o "$V/test/face.jpg" "$TEST_IMG_URL" || echo "（テスト画像は取れませんでした。iPad の計測には不要です）"
fi
echo "準備できました：$PWD/$V"
