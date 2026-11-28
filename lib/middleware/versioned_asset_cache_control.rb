# public/ の静的ファイルのうち、URL に版やハッシュが入っているものだけを長期キャッシュにする。
#
# config.public_file_server.headers は public/ の全ファイルに同じヘッダーを付けるので使わない
# （版の無い favicon・robots.txt・LICENSE などが古いまま残ってしまう）。
# 長期キャッシュにする URL は「中身を変える時は URL も変える」ものに限る。同じ URL の中身を上書きしない。
#
# - /mediapipe/tasks-vision/1.2.3/...                 MediaPipe の WASM（版を URL に入れて写す。script/copy_mediapipe_wasm.mjs）
# - /mediapipe/models/face_landmarker-float16-1.task  モデル（末尾の数字が版）
# - /assets/application-<64 桁のハッシュ>.js など      sprockets がハッシュを付けたファイル
class VersionedAssetCacheControl
  # 1 年（31,536,000 秒）。起動の早い段階で読むので ActiveSupport の 1.year は使わない
  CACHE_CONTROL = "public, max-age=31536000, immutable".freeze

  VERSIONED_PATHS = [
    %r{\A/mediapipe/tasks-vision/\d+\.\d+\.\d+/[^/]+/[\w.-]+\z},
    %r{\A/mediapipe/models/[\w-]+-\d+\.task\z},
    %r{\A/assets/[\w/.-]+-\h{64}(?:\.[\w-]+)+\z}
  ].freeze

  CACHEABLE_STATUSES = [ 200, 206, 304 ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if cacheable?(env, status)
      # 静的配信が付けた Cache-Control（環境によって名前の大文字小文字が違う）を置き換える
      headers.delete_if { |name, _| name.casecmp?(Rack::CACHE_CONTROL) }
      headers[Rack::CACHE_CONTROL] = CACHE_CONTROL
    end

    [ status, headers, body ]
  end

  private

  def cacheable?(env, status)
    CACHEABLE_STATUSES.include?(status) &&
      %w[GET HEAD].include?(env[Rack::REQUEST_METHOD]) &&
      VERSIONED_PATHS.any? { |pattern| pattern.match?(env[Rack::PATH_INFO]) }
  end
end
