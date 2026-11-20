#!/usr/bin/env bash
# hooks の単体テスト。Claude Code が渡すのと同じ形の JSON を標準入力に流し、終了コードを確かめる。
# コマンドは実行しない（判定だけ）。使い方: .claude/hooks/test/run.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hooks="$(dirname "$here")"
fail=0

# 作業ブランチ上／main 上の空リポジトリを用意し、CLAUDE_PROJECT_DIR として渡す。
work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
git init -q -b feature/x "$work/on-feature"
git init -q -b main "$work/on-main"

# $1: hook スクリプト名、$2: CLAUDE_PROJECT_DIR、$3: 入力 JSON。終了コードを表示する。
run_hook() {
  HOME=/home/tester CLAUDE_PROJECT_DIR="$2" "$hooks/$1" <<<"$3" >/dev/null 2>&1
  echo $?
}

# $1: 期待する終了コード、$2: 実際、$3: 見出し。
check() {
  if [ "$1" = "$2" ]; then
    printf 'ok    exit %s  %s\n' "$2" "$3"
  else
    printf 'FAIL  exit %s（期待 %s）  %s\n' "$2" "$1" "$3"
    fail=1
  fi
}

bash_input() {
  ruby -rjson -e 'puts JSON.generate(
    session_id: "test", cwd: Dir.pwd, permission_mode: "default",
    hook_event_name: "PreToolUse", tool_name: "Bash",
    tool_input: { command: ARGV[0], description: "test" }, tool_use_id: "toolu_test")' "$1"
}

echo "== block-dangerous-bash.sh（作業ブランチ上） =="
while IFS=$'\t' read -r expected command; do
  case "$expected" in ''|'#'*) continue ;; esac
  check "$expected" "$(run_hook block-dangerous-bash.sh "$work/on-feature" "$(bash_input "$command")")" "$command"
done <"$here/cases.tsv"

echo "== block-dangerous-bash.sh（main ブランチ上） =="
check 2 "$(run_hook block-dangerous-bash.sh "$work/on-main" "$(bash_input 'git push')")" "git push"
check 2 "$(run_hook block-dangerous-bash.sh "$work/on-main" "$(bash_input 'git push -u origin')")" "git push -u origin"
check 0 "$(run_hook block-dangerous-bash.sh "$work/on-main" "$(bash_input 'git push origin feature/x')")" "git push origin feature/x"
check 0 "$(run_hook block-dangerous-bash.sh "$work/on-main" "$(bash_input 'git status')")" "git status"

echo "== block-dangerous-bash.sh（保護ツリーの中で動かしているときは、その判定をしない） =="
check 0 "$(run_hook block-dangerous-bash.sh /home/tester/Projects/Mabatalk "$(bash_input 'cd /home/tester/Projects/Mabatalk && git status')")" "cd /home/tester/Projects/Mabatalk && git status"

echo "== block-dangerous-bash.sh（壊れた入力は止める） =="
check 2 "$(run_hook block-dangerous-bash.sh "$work/on-feature" 'not json')" "not json"

echo "== rubocop-changed.sh（.rb 以外と、無いファイルは何もしない） =="
check 0 "$(run_hook rubocop-changed.sh "$work/on-feature" '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/home/tester/x/README.md"}}')" "README.md"
check 0 "$(run_hook rubocop-changed.sh "$work/on-feature" '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/home/tester/x/missing.rb"}}')" "missing.rb"

echo "== stop-lint-changed.sh（続行中と、変更なしは止めない） =="
check 0 "$(run_hook stop-lint-changed.sh "$work/on-feature" '{"hook_event_name":"Stop","stop_hook_active":true}')" "stop_hook_active: true"
check 0 "$(run_hook stop-lint-changed.sh "$work/on-feature" '{"hook_event_name":"Stop","stop_hook_active":false}')" "変更した .rb なし"

if [ "$fail" = 0 ]; then echo "すべて期待どおり"; else echo "期待と違う結果があります"; fi
exit "$fail"
