require 'rails_helper'

# ご意見箱の添付画像は、利用者の画面の写り込み（個人情報）を含みうる。
# 画像の URL を知っていても、管理者としてログインしていなければ中身を取れないことを確かめる。
RSpec.describe "ご意見箱の添付画像を見られる人", type: :request do
  let(:png_bytes) { file_fixture("screenshot.png").binread }
  let(:admin) { create(:user, admin: true) }
  let(:general_user) { create(:user, admin: false) }

  let!(:feedback) { send_feedback }
  let(:blob) { feedback.screenshots.first.blob }

  # テストで保存した画像のファイル（tmp/storage の下）を、例ごとに片付ける。
  before { @blob_ids_before_example = ActiveStorage::Blob.ids }
  after { ActiveStorage::Blob.where.not(id: @blob_ids_before_example).find_each(&:delete) }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:admin, :email).and_return("admin@example.com")
  end

  def send_feedback
    upload = Rack::Test::UploadedFile.new(file_fixture("screenshot.png").to_s, "image/png", true)
    post feedbacks_path, params: { feedback: { category: "bug", body: "画面が崩れています", screenshots: [ upload ] } }
    Feedback.last
  end

  # 管理者が管理画面の詳細を開いたときに出ている画像の URL（<img src>）。取り出したらログアウトする
  def image_url_on_admin_page(target = feedback)
    sign_in admin
    get admin_feedback_path(target)
    expect(response).to have_http_status(:ok)
    urls = Nokogiri::HTML(response.body).css("main img").map { |img| img["src"] }
    sign_out admin
    expect(urls.size).to eq(1)
    urls.first
  end

  def notification_mail
    FeedbackMailer.notify_admin(feedback)
  end

  # 通知メール（HTML）の、スクリーンショットへのリンク
  def image_url_in_html_mail
    links = Nokogiri::HTML(notification_mail.html_part.body.decoded).css("ul a").map { |a| a["href"] }
    expect(links.size).to eq(1)
    links.first
  end

  # 通知メール（テキスト）の、スクリーンショットの URL（「1. http://…」の行）
  def image_url_in_text_mail
    urls = notification_mail.text_part.body.decoded.scan(%r{^\s*\d+\.\s+(https?://\S+)}).flatten
    expect(urls.size).to eq(1)
    urls.first
  end

  # URL を開く（リダイレクトがあればたどる）
  def open_url(url)
    get url
    follow_redirect! while response.redirect?
    response
  end

  def expect_image_not_served(url)
    open_url(url)

    expect(response).to have_http_status(:not_found)
    expect(response.body.b).not_to eq(png_bytes)
  end

  def expect_image_served(url)
    open_url(url)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.body.b).to eq(png_bytes)
  end

  shared_examples "管理者だけが開ける画像の URL" do
    it "ログインなしでは開けない（404）" do
      url = image_url

      expect_image_not_served(url)
    end

    it "一般ユーザーでは開けない（404）" do
      url = image_url
      sign_in general_user

      expect_image_not_served(url)
    end

    it "管理者は開けて、送った画像そのものが返る" do
      url = image_url
      sign_in admin

      expect_image_served(url)
    end
  end

  describe "管理画面の詳細に出ている画像の URL" do
    let(:image_url) { image_url_on_admin_page }

    it_behaves_like "管理者だけが開ける画像の URL"

    it "管理者に返す画像は、ブラウザや途中のサーバーに保存させない（Cache-Control: no-store）" do
      url = image_url
      sign_in admin
      open_url(url)

      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["Content-Disposition"]).to start_with("inline").and include("screenshot.png")
    end
  end

  describe "通知メール（HTML）の中の画像の URL" do
    let(:image_url) { image_url_in_html_mail }

    it_behaves_like "管理者だけが開ける画像の URL"
  end

  describe "通知メール（テキスト）の中の画像の URL" do
    let(:image_url) { image_url_in_text_mail }

    it_behaves_like "管理者だけが開ける画像の URL"
  end

  describe "URL の中身を入れ替えた場合（管理者でも 404）" do
    before { sign_in admin }

    it "別のご意見の画像を、このご意見の URL の下で指定しても開けない" do
      other_feedback = send_feedback
      url = image_url_on_admin_page(other_feedback)
      sign_in admin
      swapped = url.sub(other_feedback.key, feedback.key)
      expect(swapped).not_to eq(url)

      expect_image_not_served(swapped)
    end

    it "ご意見に付いていない画像（Feedback の添付ではない blob）は開けない" do
      url = image_url_on_admin_page
      sign_in admin
      feedback.screenshots.first.delete # 添付の行だけ消す。blob とファイルは残る

      expect_image_not_served(url)
    end

    it "存在しないご意見の key では開けない" do
      url = image_url_on_admin_page
      sign_in admin

      expect_image_not_served(url.sub(feedback.key, SecureRandom.uuid))
    end

    it "でたらめな画像の id では開けない" do
      url = image_url_on_admin_page
      sign_in admin

      expect_image_not_served(url.sub(%r{[^/]+\z}, "detarame"))
    end

    it "画像のファイルがディスクから消えている場合は 404 になる" do
      url = image_url_on_admin_page
      sign_in admin
      blob.service.delete(blob.key)

      expect_image_not_served(url)
    end
  end

  # Active Storage が最初から用意している URL。ログインを確かめずに画像を返すので、
  # signed_id（画像を指す署名つきの id）を知っている人なら誰でも開けてしまう。
  describe "Active Storage の公開 URL に signed_id を入れた場合" do
    let(:signed_id) { blob.signed_id }
    let(:variation_key) { ActiveStorage::Variation.encode(resize_to_limit: [ 10, 10 ]) }
    # Disk サービスが作る一時 URL と同じ作り方（activestorage の lib/active_storage/service/disk_service.rb）
    let(:disk_key) do
      ActiveStorage.verifier.generate(
        { key: blob.key, disposition: "inline; filename=\"screenshot.png\"", content_type: "image/png", service_name: blob.service_name },
        expires_in: 5.minutes, purpose: :blob_key
      )
    end
    let(:public_paths) do
      {
        "blobs/redirect" => "/rails/active_storage/blobs/redirect/#{signed_id}/screenshot.png",
        "blobs/proxy" => "/rails/active_storage/blobs/proxy/#{signed_id}/screenshot.png",
        "blobs（短い形）" => "/rails/active_storage/blobs/#{signed_id}/screenshot.png",
        "representations/redirect" => "/rails/active_storage/representations/redirect/#{signed_id}/#{variation_key}/screenshot.png",
        "representations/proxy" => "/rails/active_storage/representations/proxy/#{signed_id}/#{variation_key}/screenshot.png",
        "representations（短い形）" => "/rails/active_storage/representations/#{signed_id}/#{variation_key}/screenshot.png",
        "disk" => "/rails/active_storage/disk/#{disk_key}/screenshot.png"
      }
    end

    [ "blobs/redirect", "blobs/proxy", "blobs（短い形）",
      "representations/redirect", "representations/proxy", "representations（短い形）", "disk" ].each do |name|
      it "#{name}: ログインなしでは取れない（404）" do
        expect_image_not_served(public_paths.fetch(name))
      end

      it "#{name}: 一般ユーザーでは取れない（404）" do
        sign_in general_user

        expect_image_not_served(public_paths.fetch(name))
      end
    end

    it "ログインなしでファイルをアップロードする口（direct_uploads）も無い（404）" do
      expect do
        post "/rails/active_storage/direct_uploads",
             params: { blob: { filename: "x.png", byte_size: 100, checksum: "abc", content_type: "image/png" } }, as: :json
      end.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
