# CLAUDE.md

このファイルは AI（Claude Code）が本リポジトリで安全に作業するための最小ルール。
README内容は繰り返さない。

---

## 基本方針

- 変更は小さく・局所的に
- 大規模リファクタ禁止
- 設計の美しさより UX 安定を優先
- 既存パターンを必ず踏襲（独自抽象化を増やさない）

---

## 絶対に壊してはいけないルール

### Shared Defaults

`user_id: nil` は全ユーザー共通デフォルト。

- 取得時は必ず既存の `for_user(user)` スコープを使う
- raw な `where` で置き換えない
- 既存の `user_id: nil` レコードを更新・削除しない

### Snapshot パターン

`MessageLog` は以下を保持する：

- `message_category_name`
- `flow_item_name`

- 表示は `log.flow_item_name` を使う
- `log.flow_item.name` に戻さない
- snapshot カラムを削除しない

### セキュリティ

- UI表示制御はセキュリティではない
- コントローラーで必ず current_user スコープを適用
- 整数IDを外部公開しない（UUIDキーを使う）

---

## i18n

- Viewに日本語直書き禁止
- 必ず `t()` を使用
- 新規文言は `config/locales/ja.yml` に追加

---

## マイグレーション

- 既存データを壊さない変更のみ行う
- カラム削除は原則行わない（不要なら deprecated コメントを付けるだけ）
- NOT NULL 制約の追加は、既存レコードへのデフォルト値設定後に行う
- カラム名変更は「新カラム追加 → データ移行 → 旧カラム削除」の3段階で行う

---

## フロントエンド

- DaisyUI 優先
- カスタム CSS 最小限
- `app/assets/builds/` はコミットしない

---

## 実装前に宣言

- 何を変更するか
- なぜ変更するか
- どのファイルを触るか

---

## 実装完了条件（必須）

```bash
bin/rails db:prepare
bin/rubocop -f github
bin/brakeman --no-pager
```

すべて成功して初めて完了。

テストは RSpec で実施する（`bundle exec rspec`）。

---

## ブランチ運用

- main へ直接 push 禁止
- `feature/<機能名>`、`fix/<内容>`、`hotfix/<内容>`、`chore/<内容>` など一般的なプレフィックスを使う

## PRフロー

- 実装完了後は必ず PR を作成する
- CI（RuboCop・Brakeman・RSpec）が全て通過してからマージする
- Claude は自動でマージしない。マージはユーザーが行う

---

## コミット提案

実装の区切りごとに、実務想定の粒度でコミット候補（対象ファイル・メッセージ）を提示する。
ユーザーが確認・承認してからコミットする。

コミットメッセージに以下を含めない：
- `Co-Authored-By: Claude ...`
- `🤖 Generated with Claude Code`

---

## issue 完了後の Obsidian 記録

実装完了後、以下に設計・実装の解説ノートを追加する。

- Vault: `<ローカルのObsidian VaultのMabaTalkアーキテクチャフォルダー>`
- 既存ファイル（`deletion-policy.md` 等）のフォーマットに合わせる
- 必須セクション: 背景・コード・トレードオフ・面接での語り方・関連ドキュメント

---

## 不明点がある場合

1. 既存の類似実装を読む
2. 既存設計を優先
3. 新しい抽象化を作らない
4. それでも判断できない場合はユーザーに確認する

---

## 失敗の資産化（error taxonomy）

同じ失敗を二度踏まないため、失敗はその場で流さず memory に資産化する。
仕組みの生死は「トリガー」で決まる。分類の綺麗さより **書く習慣** を優先する。

### 記録トリガー（いずれかに当たったら失敗メモを1件書く）

- 同じ過ちを 2 回目にやった
- 1 つの詰まりに 30 分以上溶かした
- 本番 / デプロイ / 環境固有の罠で詰まった
- レビューで critical / major を食らった設計判断
- 既存データを壊しかけた（未然に防いだものも記録する）

### 分類（ゆるいタグ・履歴準拠。当てはまらなければ新設してよい）

- `infra-deploy` — 本番・デプロイ・環境固有（例: NeonDB Pooled URL で migration 死亡）
- `ai-orchestration` — AI 活用時の失敗（例: トークン枯渇・ドリフト・検証漏れ）
- `data-migration` — 既存データ破壊系
- `design` — 設計判断ミス
- `spec-misunderstanding` — 要件・仕様の取り違え

### 形式（新しい抽象を作らない）

- 置き場所: `memory/` に既存の `type: feedback` フォーマットで「1 ファイル 1 失敗」
- frontmatter の metadata に `failure_category: <上記タグ>` を足す
- 本文は既存どおり: 何が起きたか → **Why:**（根本原因）→ **How to apply:**（再発防止）
- `MEMORY.md` の「## 失敗ログ」に 1 行追記して索引する

分類は失敗が溜まってから最適化する（漸進的改善）。今は書くことを最優先。

---

## 実装後の理解確認（必要なときだけ）

実装後の理解確認（15 問）と成長優先モードは、必要なとき（ユーザーが学びたいとき）に
`.claude/skills/understanding-check/SKILL.md` を読んで行う。

- 既定では行わない。Orca 経由の作業でも既定で行わない
- 行わない場合も「実装前に宣言」は必須

---

## Codex レビュー

Codex レビュー（`.claude/skills/codex-discussion/SKILL.md`）は大きい PR だけ必須：

- Rails / Ruby のアップグレード
- 設計変更
- 認証・権限まわりの大きな変更

小さいバグ修正やテスト追加は、テストと hooks（`.claude/settings.json`）で足りる。
