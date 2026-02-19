# CLAUDE.md

Claude Code がこのリポジトリで作業する際のガイドライン。

## アプリ概要

**MabaTalk** — 重度身体障害者（まばたきのみでコミュニケーションをとる方など）を支援する Rails 7.2 製 Web アプリ。介護者がカスタマイズ可能なカテゴリからメッセージを選択し、利用者が yes/no で応答する。すべての応答はログに記録・共有可能。

## コマンド

### 開発サーバー

```bash
./bin/dev         # Rails + esbuild + Tailwind を起動 (Foreman/Procfile.dev)
bin/setup         # 初回セットアップ (依存関係インストール + DB 準備)
docker-compose up # Docker での代替起動
```

### Assets

```bash
npm run build       # esbuild で JavaScript をバンドル
npm run build:css   # Tailwind CSS をコンパイル
```

### Database

```bash
bin/rails db:prepare   # DB 作成 + migrate + seed (いつでも安全に実行可)
bin/rails db:migrate   # pending な migration を実行
bin/rails db:seed      # デフォルトカテゴリ・アイテムを投入
```

### テスト

```bash
bin/rails test          # ユニットテスト
bin/rails test:system   # システムテスト (Capybara + Selenium)
```

### Lint & セキュリティ

```bash
bin/rubocop -f github                      # Ruby スタイルチェック (rubocop-rails-omakase)
bin/brakeman --no-pager || [ $? -eq 5 ]    # セキュリティスキャン (exit 5 = 問題なし)
```

## アーキテクチャ

### Stack

- **Backend:** Ruby 3.3.6, Rails 7.2.3, PostgreSQL
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS 4.x, DaisyUI 5.x
- **Auth:** Devise + Google OAuth2
- **Bundling:** esbuild (JS), Lightning CSS / Tailwind CLI (CSS)
- **Locale:** `:ja` デフォルト、Asia/Tokyo タイムゾーン

### Domain Model

```
User (Devise)
├── has_many :message_categories
├── has_many :flow_items
└── has_many :message_logs

MessageCategory (user_id が null → 全ユーザー共通のデフォルト)
└── has_many :flow_items

FlowItem (user_id が null → 全ユーザー共通のデフォルト)
└── has_many :message_logs

MessageLog (監査ログ)
├── belongs_to :user
├── belongs_to :flow_item
└── message_category_name, flow_item_name  # 非正規化スナップショット
```

### 主要パターン

**Shared Defaults:** `user_id: null` のカテゴリ・FlowItem は全ユーザーに表示されるグローバルデフォルト。`for_user(user)` スコープでユーザー固有レコードとデフォルトを結合する。

**UUID Keys:** `message_categories.key` と `flow_items.key` は `SecureRandom.uuid` を格納（`before_validation :set_key` で自動設定）。整数 ID の列挙攻撃を防ぐ。

**Snapshot Pattern:** `MessageLog` はログ記録時点の `message_category_name` と `flow_item_name` を保存。カテゴリ・アイテムが後から削除されても履歴を保持できる。

### メッセージ選択フロー

```
/message_categories                              → カテゴリ選択
/message_categories/:id/flow_items               → アイテム選択
/message_categories/:id/flow_items/:id/confirm   → 確認 (yes/no UI)
POST /message_logs                               → ログ保存
/message_completion                              → 完了画面
```

カテゴリ・FlowItem の CRUD には認証が必要。選択・確認フローはログイン不要（未認証の介護者でも使えるが、ログは保存されない）。

### Frontend

- **Stimulus controllers:** `app/javascript/controllers/`
- **Tailwind source:** `app/assets/stylesheets/application.tailwind.css`（コンパイル結果の `app/assets/builds/` はコミットしない）
- コンポーネントは DaisyUI のクラスを優先し、カスタム CSS は最小限に

### Authentication

Devise の設定: `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`, `omniauthable` (Google OAuth2)。

Google OAuth コールバック: `app/controllers/users/omniauth_callbacks_controller.rb` の `User.from_omniauth`。

### 開発環境のメール

`letter_opener_web` でメールをキャプチャ。`/letter_opener` にアクセスしてプレビュー（SMTP サーバー不要）。

### i18n

ユーザー向け文字列は必ず Rails i18n を使う。Locale ファイルは `config/locales/`。View に日本語をハードコードしない。

## CI (GitHub Actions)

`.github/workflows/ci.yml` で以下を実行:
1. **Brakeman** — セキュリティスキャン
2. **RuboCop** — スタイル Lint

テストは設定済みだが CI では現在無効。

## 2週間リリース戦略

機能開発から本番リリースまでの標準的な 2 週間スプリントサイクル。

### 開発ポリシー（最優先）

- 過剰設計しない
- 大規模リファクタは禁止（致命的問題を除く）
- まず動くものを優先
- UX安定を最優先
- テストは重要だが、出荷を止めるほど完璧を求めない
- 1機能ずつ小さく出す
- 迷ったらシンプルな実装を選ぶ

### Week 1: 開発フェーズ

| 日程 | アクティビティ |
|------|--------------|
| Day 1–2 | 要件確認・タスク分解・feature ブランチ作成 |
| Day 3–5 | 実装（モデル → コントローラ → View の順） |
| Day 6–7 | ユニットテスト・システムテスト作成、Brakeman / RuboCop をクリア |

### Week 2: 検証・リリースフェーズ

| 日程 | アクティビティ |
|------|--------------|
| Day 8–9 | PR 作成・コードレビュー・フィードバック対応 |
| Day 10–11 | ステージング環境での動作確認・回帰テスト |
| Day 12 | main へのマージ・本番 deploy |
| Day 13–14 | 本番モニタリング・不具合があれば hotfix |

### ブランチ運用ルール

```
main          ← 本番。直接 push 禁止
  └── feature/<機能名>   ← 開発用（PR 経由で main にマージ）
  └── hotfix/<説明>      ← 本番障害の緊急修正
```

### リリース前チェックリスト

- [ ] `bin/rails test` がすべて通過
- [ ] `bin/brakeman` で脆弱性なし
- [ ] `bin/rubocop` でスタイル違反なし
- [ ] `db/migrate` の migration が正常に動作する
- [ ] i18n キーの抜け漏れなし (`config/locales/`)
- [ ] PR に変更内容・テスト方法・スクリーンショットを記載
