#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): 編集された .rb だけを rubocop にかける。
# 編集はもう終わっているので取り消せない。違反は終了コード 2 + 標準エラーで Claude に見せる。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
file="$(hook_json_get "$input" tool_input.file_path)" || exit 0

# .rb 以外と、消えたファイルは何もしない。
case "$file" in
  *.rb) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

cd "$(hook_project_dir)"

status=0
out="$(hook_rubocop "$file")" || status=$?

case "$status" in
  0) exit 0 ;;
  1)
    {
      echo "rubocop: 編集したファイルに違反があります。直してください。"
      echo "$out"
    } >&2
    exit 2
    ;;
  *)
    # rubocop 自体が動かなかった（ruby や gem が無いなど）。作業は止めない。
    echo "rubocop-changed: bin/rubocop を実行できませんでした（終了コード ${status}）。" >&2
    exit 1
    ;;
esac
