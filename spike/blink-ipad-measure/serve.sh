#!/usr/bin/env bash
# iPad で開くための一発コマンド。
#   1) vendor を用意（初回だけダウンロード、ハッシュ確認）
#   2) 127.0.0.1:8787 で配る
#   3) cloudflared のクイックトンネルで https://〜.trycloudflare.com を作る（アカウント不要）
# Ctrl+C で全部止まる。トンネルの URL は毎回変わり、止めれば使えなくなる。
set -euo pipefail
cd "$(dirname "$0")"
PORT=${PORT:-8787}
./setup.sh
if ! command -v cloudflared >/dev/null; then
  echo "cloudflared が無いので入れます（brew install cloudflared）"
  brew install cloudflared
fi
node server.mjs & SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 0.5
echo "Mac で確かめるとき：http://localhost:$PORT/"
echo "下に出る https://〜.trycloudflare.com を iPad の Safari で開いてください。"
cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" 2>&1 | grep --line-buffered -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' | while read -r url; do
  echo
  echo "=============================================="
  echo " iPad で開く URL： $url"
  echo "=============================================="
  printf '%s' "$url" | pbcopy && echo "（クリップボードにコピーしました。同じ Apple ID の iPad ならペーストできます）"
done
