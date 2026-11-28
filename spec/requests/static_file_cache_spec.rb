require 'rails_helper'

# public/ の静的ファイルのキャッシュ（lib/middleware/versioned_asset_cache_control.rb）。
# URL に版やハッシュが入っているファイルだけを長期キャッシュにし、それ以外は今まで通りにする。
RSpec.describe "静的ファイルのキャッシュ", type: :request do
  let(:long_cache) { "public, max-age=31536000, immutable" }

  describe "まばたき入力のモデル（git に入っている実物）" do
    let(:model_path) { "/mediapipe/models/face_landmarker-float16-1.task" }

    it "長期キャッシュで返す" do
      get model_path

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq(long_cache)
      expect(response.headers["Content-Length"]).to eq("3758596")
      expect(response.media_type).to eq("application/octet-stream")
    end

    it "置いたファイルの SHA-256 が記録どおり（取り違え・改行の変換で壊れていない）" do
      digest = Digest::SHA256.file(Rails.public_path.join(model_path.delete_prefix("/"))).hexdigest

      expect(digest).to eq("64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff")
    end
  end

  describe "版の無いファイル" do
    %w[/robots.txt /favicon.ico /mediapipe/LICENSE /mediapipe/NOTICE].each do |path|
      it "#{path} は長期キャッシュにしない" do
        get path

        expect(response).to have_http_status(:ok)
        expect(response.headers["Cache-Control"]).not_to include("immutable")
      end
    end
  end

  describe "LICENSE と NOTICE" do
    it "Apache License 2.0 の全文と、配っているファイルの出所・ハッシュを置いている" do
      license = Rails.public_path.join("mediapipe/LICENSE").read
      notice = Rails.public_path.join("mediapipe/NOTICE").read

      expect(license).to include("Apache License", "Version 2.0, January 2004", "END OF TERMS AND CONDITIONS")
      expect(notice).to include(
        "@mediapipe/tasks-vision 1.2.3",
        "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff",
        "/mediapipe/tasks-vision/1.2.3/wasm/vision_wasm_module_internal.wasm"
      )
    end
  end

  # WASM は yarn build が写すので、テストを動かす環境に無いこともある。ここは middleware だけを確かめる
  describe VersionedAssetCacheControl do
    let(:static_headers) { { "Cache-Control" => "public, max-age=3600", "content-type" => "text/plain" } }

    def call(path, method: "GET", status: 200)
      app = ->(_env) { [ status, static_headers.dup, [ "body" ] ] }
      env = Rack::MockRequest.env_for(path, method: method)
      _status, headers, _body = described_class.new(app).call(env)
      headers.select { |name, _| name.casecmp?("cache-control") }
    end

    {
      "/mediapipe/tasks-vision/1.2.3/wasm/vision_wasm_module_internal.wasm" => "WASM",
      "/mediapipe/tasks-vision/1.2.3/wasm/vision_wasm_module_internal.js" => "WASM の loader",
      "/assets/application-#{'a' * 64}.js" => "ハッシュ付きの JS",
      "/assets/application-#{'0' * 64}.css" => "ハッシュ付きの CSS",
      "/assets/application.js-#{'b' * 64}.map" => "ハッシュ付きの source map"
    }.each do |path, label|
      it "#{label}（#{path}）は長期キャッシュにする（元の Cache-Control は残さない）" do
        expect(call(path)).to eq("cache-control" => long_cache)
      end
    end

    {
      "/mediapipe/tasks-vision/latest/wasm/vision_wasm_module_internal.wasm" => "版が数字でない",
      "/mediapipe/models/face_landmarker.task" => "モデルの名前に版が無い",
      "/mediapipe/LICENSE" => "LICENSE",
      "/assets/application.js" => "ハッシュの無い assets",
      "/assets/application-abc123.js" => "ハッシュが短い",
      "/robots.txt" => "robots.txt",
      "/message_categories" => "ふつうの画面"
    }.each do |path, label|
      it "#{label}（#{path}）はそのまま" do
        expect(call(path)).to eq("Cache-Control" => "public, max-age=3600")
      end
    end

    it "見つからなかった時（404）は長期キャッシュにしない" do
      expect(call("/mediapipe/tasks-vision/1.2.3/wasm/nothing.wasm", status: 404)).to eq("Cache-Control" => "public, max-age=3600")
    end

    it "GET と HEAD 以外は長期キャッシュにしない" do
      expect(call("/assets/application-#{'a' * 64}.js", method: "POST")).to eq("Cache-Control" => "public, max-age=3600")
      expect(call("/assets/application-#{'a' * 64}.js", method: "HEAD")).to eq("cache-control" => long_cache)
    end
  end
end
