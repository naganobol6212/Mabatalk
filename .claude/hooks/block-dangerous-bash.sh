#!/usr/bin/env bash
# PreToolUse(Bash): 取り返しのつかないコマンドを実行前に止める。
# 終了コード 2 で阻止し、標準エラーの理由が Claude に渡る。
# 文字列の一致で判定するので、引用符の中に書いただけでも止まることがある（安全側に倒している）。
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
if ! cmd="$(hook_json_get "$input" tool_input.command)"; then
  echo "block-dangerous-bash: hook の入力 JSON を読めません（ruby か python3 が必要）。安全のため実行を止めました。" >&2
  exit 2
fi
[ -n "$cmd" ] || exit 0

block() {
  echo "block-dangerous-bash: $1" >&2
  echo "このコマンドは .claude/hooks/block-dangerous-bash.sh が止めました。必要な操作ならユーザーに依頼してください。" >&2
  exit 2
}

sp='[[:space:]]'

# コマンド全体を拡張正規表現（大文字小文字を区別しない）で調べる。
has() { grep -Eiq -- "$1" <<<"$cmd"; }

# && || ; | で区切った 1 コマンドずつ。「git push ... && gh pr create --base main」の
# main を push の引数と取り違えないために使う。
segments="$(sed -e 's/&&/;/g' -e 's/||/;/g' <<<"$cmd" | tr ';|' '\n\n')"
# $( ) やバッククォートの中に書いたコマンドも見つけるため、そこでも区切った行を足す。
# 元の行も残すので、引数の確認は区切る前の 1 コマンド全体に対して行われる。
segments="${segments}
$(sed -e 's/\$(/;/g' <<<"$segments" | tr ';`' '\n\n')"
# 実行するまで中身が決まらないもの（$( )、バッククォート、$変数）。
dynamic='\$|`'
# 区切ったコマンドの先頭。次のものは読み飛ばして、その後ろの rm / git を見つける:
# sudo や xargs などの前置き、bash -c / eval と引用符、$( )、VAR=値、/bin/ のようなパス、\rm の \。
head="^[[:space:](]*((sudo|env|xargs|command|time|exec|nohup|nice|eval|then|do|else)${sp}+(-[^[:space:]]+${sp}+)*|(bash|sh|zsh)${sp}+(-[a-zA-Z]+${sp}+)*|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*${sp}+|[\"'\`{]${sp}*|\\\$\\(${sp}*)*([^[:space:]]*/)?\\\\?"

# --- 強制 push と main/master への直接 push ---
git_push="${head}git(${sp}+-[^[:space:]]+(${sp}+[^-[:space:]][^[:space:]]*)?)*${sp}+push(${sp}|\$)"
push_lines="$(grep -E -- "$git_push" <<<"$segments" || true)"
if [ -n "$push_lines" ]; then
  in_push() { grep -Eq -- "$1" <<<"$push_lines"; }

  if in_push "${sp}(--force|--force-with-lease|--force-if-includes|-[a-zA-Z]*f[a-zA-Z]*)(=|${sp}|[\"')]|\$)" \
    || in_push "${sp}\\+[^[:space:]]+"; then
    block "強制 push（--force / -f / --force-with-lease / +refspec）は禁止です。"
  fi
  if in_push "(${sp}|:|/)(main|master)[\"']?(${sp}|\\)|\$)"; then
    block "main / master への直接 push は禁止です。作業ブランチを push して PR を作ってください。"
  fi
  if in_push "$dynamic"; then
    block "変数やコマンド置換を含む push は、push 先を事前に確かめられないので禁止です。ブランチ名をそのまま書いてください。"
  fi
  # push 先のブランチを書いていない（引数がリモート名までの）push は、
  # 今いるブランチが main / master なら止める。
  current="$(git -C "$(hook_project_dir)" branch --show-current 2>/dev/null || true)"
  if [ "$current" = "main" ] || [ "$current" = "master" ]; then
    while IFS= read -r line; do
      args="$(sed -E -e 's/^.*[[:space:]]push//' -e 's/[[:space:]]-[^[:space:]]*//g' <<<"$line")"
      [ "$(wc -w <<<"$args")" -ge 2 ] || block "現在のブランチが ${current} です。main / master からの push は禁止です。"
    done <<<"$push_lines"
  fi
fi

# --- rm -rf（-fr、-Rf、-r -f、--recursive --force も） ---
rm_lines="$(grep -E -- "${head}rm${sp}" <<<"$segments" || true)"
if [ -n "$rm_lines" ]; then
  in_rm() { grep -Eq -- "$1" <<<"$rm_lines"; }
  if { in_rm "${sp}-[a-zA-Z]*[rR]" || in_rm "${sp}--recursive"; } \
    && { in_rm "${sp}-[a-zA-Z]*f" || in_rm "${sp}--force"; }; then
    block "rm -rf（再帰＋強制の削除）は場所を問わず禁止です。消す対象を確かめ、-f なしで個別に消してください。"
  fi
  if in_rm '\$\(|`'; then
    block "コマンド置換を含む rm は、オプションと対象を事前に確かめられないので禁止です。対象をそのまま書いてください。"
  fi
fi

# --- データベースの破壊 ---
if has "drop${sp}+(table|database)"; then
  block "DROP TABLE / DROP DATABASE は禁止です。"
fi
if has 'db:(drop|reset)'; then
  block "db:drop / db:reset は禁止です（既存データを壊します）。"
fi

# --- 本番への操作 ---
if has '(RAILS_ENV|RACK_ENV)=["'"'"']?production' \
  || has "(rails|rake|bin/)[^;&|]*${sp}(-e|--environment)[=[:space:]]+production"; then
  block "本番環境（production）を指定したコマンドは禁止です。"
fi
if grep -Eq -- "${head}render${sp}+(deploy|deploys|restart|ssh|psql|jobs?|services?|blueprints?)" <<<"$segments"; then
  block "Render CLI による本番操作（deploy など）は禁止です。"
fi
if has 'neon\.tech' || has '\$\{?DATABASE_URL_DIRECT'; then
  block "本番データベース（NeonDB）への接続を伴うコマンドは禁止です。"
fi

# --- 保護するツリー（既定: ~/Projects/Mabatalk）への移動・書き込み ---
# worktree（~/orca/workspaces/Mabatalk/...）は別のパスなので当たらない。
# 保護ツリーの中で Claude Code を動かしているときは、この判定をしない。
protected="${MABATALK_PROTECTED_TREE:-$HOME/Projects/Mabatalk}"
case "$(hook_project_dir)/" in
  "$protected"/*) protected="" ;;
esac
if [ -n "$protected" ]; then
  # ~/ と $HOME と ${HOME} を実際のパスにそろえてから調べる。
  norm="$(sed -e "s#\\\${HOME}#$HOME#g" -e "s#\\\$HOME#$HOME#g" -e "s#~/#$HOME/#g" <<<"$cmd")"
  # パスの直後が英数字や . _ - なら別のディレクトリ（Mabatalk-lab など）なので当てない。
  path_re="$(sed 's#[.[\*^$]#\\&#g' <<<"$protected")(\$|[^[:alnum:]._-])"
  if grep -Eq -- "$path_re" <<<"$norm"; then
    # 読むだけのコマンド（cat / ls / grep など）は通す。移動・書き込みに使うコマンドか、
    # 保護ツリーへのリダイレクトがあれば止める。
    writes="(^|[;&|(]|${sp})(cd|pushd|rm|mv|cp|touch|mkdir|rmdir|tee|ln|chmod|chown|rsync|install|dd|truncate|patch|sed|git|bundle|npm|npx|yarn|bin/[^[:space:]]+)(${sp}|\$)"
    if grep -Eq -- "$writes" <<<"$norm" || grep -Eq -- ">${sp}*[\"']?${path_re}" <<<"$norm"; then
      block "${protected} は保護されたツリーです。そこへの移動・書き込み・git 操作は禁止です（読むだけなら cat / ls / grep を使ってください）。"
    fi
  fi
fi

exit 0
