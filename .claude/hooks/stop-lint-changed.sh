#!/usr/bin/env bash
# Stop: まだコミットしていない .rb（変更・ステージ済み・新規）だけを rubocop にかける。
# 違反が残っていれば終了コード 2 で Claude に作業を続けさせる。
# 全件 RSpec や Brakeman は遅いのでここでは走らせない。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"

# この hook のせいで続行中なら、もう止めない（無限ループ防止）。
active="$(hook_json_get "$input" stop_hook_active)" || exit 0
[ "$active" = "true" ] && exit 0

cd "$(hook_project_dir)"

# 未コミット（ステージ済みを含む）と、まだ git に入っていない新規の .rb。消したファイルは除く。
files=()
while IFS= read -r f; do
  [ -f "$f" ] && files+=("$f")
done < <(
  {
    git diff --name-only --diff-filter=d HEAD -- '*.rb' 2>/dev/null || true
    git ls-files --others --exclude-standard -- '*.rb' 2>/dev/null || true
  } | sort -u
)
[ "${#files[@]}" -gt 0 ] || exit 0

status=0
out="$(hook_rubocop "${files[@]}")" || status=$?

case "$status" in
  0) exit 0 ;;
  1)
    {
      echo "rubocop: 変更した .rb に違反が残っています。直してから終えてください。"
      echo "$out"
    } >&2
    exit 2
    ;;
  *)
    # rubocop 自体が動かなかった。終了は妨げない。
    echo "stop-lint-changed: bin/rubocop を実行できませんでした（終了コード ${status}）。" >&2
    exit 1
    ;;
esac
