require 'rails_helper'
require 'support/form_helpers'

# ご意見箱のスクリーンショット添付を、利用者と管理者の操作の順に通す。
# 送信フォーム（multipart）→ 保存 → 管理画面に画像が出る → 画像の URL を開くと送った中身が返る
RSpec.describe "ご意見箱のスクリーンショット添付", type: :request do
  let(:png_bytes) { file_fixture("screenshot.png").binread }

  # テストで保存した画像のファイル（tmp/storage の下）を、例ごとに片付ける。
  # DB の行は例が終わると巻き戻るが、ディスクに書いたファイルは残り続けるため。
  # 消すのはこの例の中で作られた分だけ（Blob#delete はファイルだけを消す）。
  before { @blob_ids_before_example = ActiveStorage::Blob.ids }
  after { ActiveStorage::Blob.where.not(id: @blob_ids_before_example).find_each(&:delete) }

  def send_feedback(*files)
    post feedbacks_path, params: { feedback: { category: "bug", body: "画面が崩れています", screenshots: files } }
  end

  def png_upload(name = "screenshot.png")
    Rack::Test::UploadedFile.new(file_fixture("screenshot.png").to_s, "image/png", true, original_filename: name)
  end

  def text_upload
    fixture_file_upload("not_an_image.txt", "text/plain")
  end

  # 管理画面の詳細に出ている画像の URL（<img src>）を取り出す
  def screenshot_image_urls(feedback)
    sign_in create(:user, admin: true)
    get admin_feedback_path(feedback)
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body).css("main img").map { |img| img["src"] }
  end

  # 画像の URL を開いて（リダイレクトをたどって）返ってきた中身
  def download(url)
    get url
    follow_redirect! while response.redirect?
    response
  end

  describe "PNG 画像を添付して送信する" do
    it "ご意見と添付ファイルが保存され、設定画面へリダイレクトされる" do
      expect { send_feedback(png_upload) }
        .to change(Feedback, :count).by(1)
        .and change(ActiveStorage::Attachment, :count).by(1)
        .and change(ActiveStorage::Blob, :count).by(1)

      expect(response).to redirect_to(settings_path)
      screenshot = Feedback.last.screenshots.first
      expect(screenshot.filename.to_s).to eq("screenshot.png")
      expect(screenshot.content_type).to eq("image/png")
      expect(screenshot.download).to eq(png_bytes)
    end

    it "管理画面の詳細に画像とファイル名が表示され、画像の URL を開くと送った画像そのものが返る" do
      send_feedback(png_upload)

      urls = screenshot_image_urls(Feedback.last)
      expect(urls.size).to eq(1)
      expect(response.body).to include("screenshot.png")

      image = download(urls.first)
      expect(image).to have_http_status(:ok)
      expect(image.media_type).to eq("image/png")
      expect(image.body.b).to eq(png_bytes)
    end

    it "上限の 3 枚まで添付でき、管理画面に 3 枚とも表示される" do
      expect { send_feedback(png_upload("a.png"), png_upload("b.png"), png_upload("c.png")) }
        .to change(ActiveStorage::Attachment, :count).by(3)

      expect(screenshot_image_urls(Feedback.last).size).to eq(3)
      expect(response.body).to include("a.png", "b.png", "c.png")
    end

    it "添付なしのご意見の詳細には画像が表示されない" do
      send_feedback

      expect(screenshot_image_urls(Feedback.last)).to be_empty
    end
  end

  # ここまでの例は送信先と欄の名前をテストに直接書いている。
  # この例は画面のフォームを読み取り、そこに書かれた送信先と欄の名前で送る。
  describe "ご意見の新規画面のフォームから送る" do
    it "画面のファイル選択欄は複数選べて、フォームの送信先へその欄の名前で送った画像が 2 枚とも保存される" do
      get new_feedback_path
      form = form_containing("input[type='file']")
      file_input = form.at_css("input[type='file']")

      # ブラウザがファイルを送るには、フォームが multipart であることが必要
      expect(form["enctype"]).to eq("multipart/form-data")
      expect(file_input["multiple"]).to be_present

      expect do
        submit_form(form, hidden_fields(form) + [
          [ form.at_css("input[type='radio'][value='bug']")["name"], "bug" ],
          [ form.at_css("textarea")["name"], "画面が崩れています" ],
          [ file_input["name"], png_upload("a.png") ],
          [ file_input["name"], png_upload("b.png") ]
        ])
      end.to change(Feedback, :count).by(1).and change(ActiveStorage::Attachment, :count).by(2)

      expect(response).to redirect_to(settings_path)
      feedback = Feedback.last
      expect(feedback.body).to eq("画面が崩れています")
      expect(feedback.screenshots.map { |screenshot| screenshot.filename.to_s }).to contain_exactly("a.png", "b.png")
      expect(feedback.screenshots.map(&:download)).to all(eq(png_bytes))
    end
  end

  describe "受け付けない添付" do
    def saved_record_counts
      [ Feedback.count, ActiveStorage::Attachment.count, ActiveStorage::Blob.count ]
    end

    def expect_rejected_with(message)
      expect(response).to have_http_status(422)
      expect(response.body).to include(message)
    end

    def screenshots_error(type, **options)
      Feedback.new.errors.full_message(:screenshots, I18n.t(type, scope: "activerecord.errors.models.feedback.attributes.screenshots", **options))
    end

    it "画像ではないファイル（テキスト）は保存されず、エラーが表示される" do
      expect { send_feedback(text_upload) }
        .not_to change { saved_record_counts }

      expect_rejected_with(screenshots_error(:invalid_content_type))
    end

    it "画像とテキストを混ぜて送ると、画像のほうも含めて何も保存されない" do
      expect { send_feedback(png_upload, text_upload) }
        .not_to change { saved_record_counts }

      expect_rejected_with(screenshots_error(:invalid_content_type))
    end

    # 枚数と文言は仕様（3 枚まで）をそのまま書く。アプリの定数から計算すると、上限を緩めても気付けない。
    it "4 枚目は受け付けず、何も保存されず、「3 枚まで」のエラーが表示される" do
      expect { send_feedback(png_upload("a.png"), png_upload("b.png"), png_upload("c.png"), png_upload("d.png")) }
        .not_to change { saved_record_counts }

      expect_rejected_with("スクリーンショットは最大3枚までです")
    end
  end

  describe "添付付きのご意見を管理者以外が見ようとした場合" do
    let(:feedback) do
      send_feedback(png_upload)
      Feedback.last
    end

    it "未ログインでは 404 になり、画像の URL も内容も返らない" do
      get admin_feedback_path(feedback)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("screenshot.png")
    end

    it "一般ユーザーでは 404 になり、画像の URL も内容も返らない" do
      sign_in create(:user, admin: false)
      get admin_feedback_path(feedback)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("screenshot.png")
    end
  end
end
