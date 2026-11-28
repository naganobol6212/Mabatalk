require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# 起動時の設定（下の config.middleware）で使うので、自動読み込みではなく先に読む
require_relative "../lib/middleware/versioned_asset_cache_control"

module Myapp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    config.time_zone = "Tokyo"
    config.active_record.default_timezone = :local

    config.i18n.default_locale = :ja
    config.i18n.available_locales = [ :ja, :en ]
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Active Storage が最初から用意する URL（/rails/active_storage/...）は、ログインを確かめずにファイルを返す。
    # 添付（ご意見箱のスクリーンショット）は管理者だけに見せるため、この URL は全環境で作らない。
    # 画像は Admin::FeedbackScreenshotsController から返す。
    config.active_storage.draw_routes = false

    # 画面ごとの機能の許可（Permissions-Policy）。カメラはこのサイトの画面だけ（まばたき入力）、マイクと位置情報は使わない。
    # Rails の permissions_policy は古い名前の Feature-Policy ヘッダーを出すので、ここで直接付ける。
    # load_defaults が default_headers を作り直すので、必ず load_defaults より後に書く。
    # 静的ファイル（public/）には付かない。Safari はこのヘッダーに対応していない（カメラは getUserMedia で audio: false にする）。
    config.action_dispatch.default_headers["Permissions-Policy"] = "camera=(self), microphone=(), geolocation=()"

    # public/ の静的ファイルのうち、版やハッシュが URL に入っているものだけを長期キャッシュにする
    config.middleware.insert_before ActionDispatch::Static, VersionedAssetCacheControl

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
