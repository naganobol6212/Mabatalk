---
name: codex-discussion
description: Claude Code で進める設計・実装・不具合調査について、Codex CLI に第三者レビューまたは往復議論を依頼する skill。依頼文作成・実行・結果回収・報告まで一貫して行う。「Codexにレビューさせて」「セカンドオピニオン」「別の視点」「クロスレビュー」と言われたら使う。本番影響のある変更・設計判断に迷いがある場合は明示がなくても使用を提案する。
---

# codex-discussion — Codex CLI への第三者レビュー依頼

Claude（Anthropic）の成果物・設計判断を、別ベンダーのモデル（OpenAI Codex）に独立レビューさせて自己バイアスを打ち消すための skill。

## この環境で確認済みの実行方法（2026-07-04 確認・codex-cli 0.132.0）

- 認証: ChatGPT アカウントで認証済み。API キー不要
- 既定モデル: `gpt-5.5` / reasoning effort `medium`（Codex CLI のユーザー設定による）
- 非対話実行は `codex exec`（承認プロンプトなしで走る。安全性はサンドボックスフラグで担保する）

### 基本形

`<リポジトリルートの絶対パス>` は実行時に `git rev-parse --show-toplevel` で解決する（個人環境のパスを直書きしない）。

```bash
codex exec \
  --sandbox read-only \
  --ephemeral \
  -C <リポジトリルートの絶対パス> \
  -o <出力ファイルの絶対パス> \
  "<依頼文>"
```

### 構造化出力が欲しい場合（推奨・正規化コストが下がる）

最終応答を JSON Schema に強制できる。スキーマをファイルに書いてから:

```bash
codex exec \
  --sandbox read-only \
  --ephemeral \
  -C <リポジトリルートの絶対パス> \
  --output-schema <スキーマファイルの絶対パス> \
  -o <出力ファイルの絶対パス> \
  "<依頼文>"
```

### 運用ルール

- **必ず `--sandbox read-only` を付ける**。Codex に本体を変更させない（`workspace-write` / `--dangerously-bypass-approvals-and-sandbox` は使用禁止）
- `--ephemeral` でセッションファイルを残さない
- `-C` でリポジトリを作業ルートにすると、Codex が対象ファイル（contextPath 等）を自分で読める。依頼文には全文を貼らず**ファイルパスを指示して読ませる**（トークン節約）
- 結果は `-o <FILE>` で回収する（stdout のイベントログはパースしない）。実行後にそのファイルを Read する
- 長い依頼文は引数でなく stdin で渡せる: `codex exec ... - < prompt.txt`（PROMPT に `-` を指定）
- モデルを変えたいときのみ `-m <MODEL>` を付ける（通常は config 既定の gpt-5.5 でよい）
- 実行は数分かかることがある。Bash ツールの timeout は 600000（10 分）に設定する
- **失敗時のフォールバック禁止**: exit code が非 0、または出力ファイルが空/存在しない場合は「Codex 実行失敗」として理由ごと報告する。**自分（Claude）が代わりにレビューして埋めてはならない**（第三者レビューの意味がなくなる）

## 依頼文の型（レビュー依頼）

```text
あなたは独立した設計レビュアーです。以下を読んでレビューしてください。

対象: <ファイルパス（例: /path/to/context.md）> を読むこと
観点: <レンズ/観点の指示>

出力形式:
- 指摘ごとに severity（critical / major / minor / info）を付ける
  - critical = このままだと動かない/壊れる、major = 高確率で問題化、minor = 改善余地、info = 補足
- 各指摘に: 一行要約（title）/ 何がどう問題か・具体的な失敗シナリオ（detail）/ 根拠となる一次情報 URL かファイルパス（evidence）/ 推奨する対処（recommendation）
- 問題なしと確認できた設計判断も「okPoints」として列挙する
- 日本語で書く
```

## strict に反証させたい場合の型

既出の指摘・主張を疑わせる（反証専用）ときは、依頼文を次の形にする:

```text
あなたは懐疑的な検証者です。以下の指摘を「反証」することだけを目的に検討してください。

対象コンテキスト: <ファイルパス> を読むこと
検証する指摘: <指摘の title / detail / evidence>

ルール:
- 指摘を支持する材料ではなく、指摘が誤り・誇張である可能性を積極的に探すこと
- 事実確認はリポジトリの実ファイルや一次情報に基づくこと。推測で判定しない
- 結論は isReal: true / false で明示し、false の場合は correction に正しい事実を書く
- 判断できない場合は isReal: true（安全側）とする
```

## 出力の扱い（呼び出し側の責務）

この skill の出力（`-o` のファイル内容）は自然言語または `--output-schema` 準拠の JSON。**呼び出し側が構造化データ（design-review.js の FINDINGS スキーマ: findings[{title, severity, detail, recommendation, evidence}] + okPoints[]）に正規化する前提**である。正規化時に情報を追加・創作しない — Codex が言っていない指摘を足さず、severity の付け直しもしない（欠損フィールドの補完のみ可）。
