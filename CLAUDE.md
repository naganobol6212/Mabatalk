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

## マイグレーション（過去の障害より）

- 作成後すぐコミット（履歴乖離防止）
- カラム追加時は `column_exists?` ガード
- `change` より `up/down`
- `down` では自分が追加したカラムのみ削除

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
bin/rails test
bin/rubocop -f github
bin/brakeman --no-pager || [ $? -eq 5 ]
```

すべて成功して初めて完了。

---

## ブランチ運用

- main へ直接 push 禁止
- `feature/<機能名>` または `hotfix/<内容>`

---

## コミット提案

実装の区切りごとに、実務想定の粒度でコミット候補（対象ファイル・メッセージ）を提示する。
ユーザーが確認・承認してからコミットする。

---

## issue 完了後の Obsidian 記録

実装完了後、以下に設計・実装の解説ノートを追加する。

- Vault: `/Users/naganoma/Obsidian Vault/01_projects/MabaTalk/architecture/`
- 既存ファイル（`deletion-policy.md` 等）のフォーマットに合わせる
- 必須セクション: 背景・コード・トレードオフ・面接での語り方・関連ドキュメント

---

## 不明点がある場合

1. 既存の類似実装を読む
2. 既存設計を優先
3. 新しい抽象化を作らない
