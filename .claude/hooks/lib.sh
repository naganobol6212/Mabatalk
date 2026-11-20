#!/usr/bin/env bash
# hooks 共通の小さな関数。各スクリプトから source する。

# 標準入力で受けた hook の JSON（$1）から、ドット区切りのキー（$2）の値を取り出す。
# jq が無い環境でも動くよう ruby → python3 の順で使う。どちらも無ければ 127 を返す。
hook_json_get() {
  local json="$1" key="$2"
  if command -v ruby >/dev/null 2>&1; then
    printf '%s' "$json" | ruby -rjson -e '
      v = ARGV[0].split(".").reduce(JSON.parse(STDIN.read)) { |h, k| h.is_a?(Hash) ? h[k] : nil }
      print v unless v.nil?' "$key"
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" | python3 -c '
import json, sys
v = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v, dict) else None
if v is not None:
    sys.stdout.write(str(v).lower() if isinstance(v, bool) else str(v))' "$key"
  else
    return 127
  fi
}

# リポジトリのルート。Claude Code が渡す CLAUDE_PROJECT_DIR を優先する。
hook_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
  else
    (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  fi
}

# 渡された .rb だけを rubocop にかけ、結果を標準出力に出す。
# 終了コード 0: 違反なし / 1: 違反あり / 3: rubocop 自体が動かなかった。
# .rubocop.yml の除外（tmp/ や db/schema.rb など）は CI と同じく守る。
hook_rubocop() {
  local out status=0
  out="$(bin/rubocop --force-exclusion --format emacs --no-color "$@" 2>&1)" || status=$?
  # PATH の ruby が古くて動かないときは、mise があれば .ruby-version の ruby でもう一度だけ試す。
  if ! _hook_rubocop_ran "$status" "$out" && command -v mise >/dev/null 2>&1; then
    status=0
    out="$(mise exec -- bin/rubocop --force-exclusion --format emacs --no-color "$@" 2>&1)" || status=$?
  fi
  if ! _hook_rubocop_ran "$status" "$out"; then
    head -n 3 <<<"$out"
    return 3
  fi
  printf '%s\n' "$out"
  return "$status"
}

# rubocop が最後まで動いたか。bundler の失敗も終了コード 1 になるので、
# 1 のときは「パス:行:列: 種別: 説明」の行があるかで違反と見分ける。
_hook_rubocop_ran() {
  case "$1" in
    0) return 0 ;;
    1) grep -Eq '^.+:[0-9]+:[0-9]+: [A-Z]: ' <<<"$2" ;;
    *) return 1 ;;
  esac
}
