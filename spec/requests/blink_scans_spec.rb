require 'rails_helper'

# まばたきスキャン画面（1 つのカテゴリの定型文を順に光らせて選ぶ画面）。
# PR2 の時点では入口のリンクが無く、URL を知っている人だけが開ける。カメラは使わず、キー操作で選ぶ。
RSpec.describe "まばたきスキャン画面", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:shared_category) { create(:message_category, user: nil, name: "のみもの") }
  let!(:shared_item) { create(:flow_item, message_category: shared_category, user: nil, name: "おちゃ", position: 1) }

  def page
    Nokogiri::HTML(response.body)
  end

  # 画面に並ぶスキャン項目（定型文＋最後の「休止」）の [key, 名前]
  def scan_items
    page.css("[data-scan-target~='item']").map { |item| [ item["data-key"], item["data-name"] ] }
  end

  def start_button
    page.at_css("button[data-action~='scan#start']")
  end

  describe "GET /message_categories/:message_category_id/blink_scan" do
    context "ゲスト（未ログイン）の場合" do
      it "共有カテゴリは 200 で開け、共有の定型文と最後に「休止」が並び、開始ボタンがある" do
        get message_category_blink_scan_path(shared_category)

        expect(response).to have_http_status(:ok)
        expect(scan_items).to eq([ [ shared_item.key, "おちゃ" ], [ "scan:pause", nil ] ])
        expect(page.at_css("[data-key='scan:pause']")["data-kind"]).to eq("pause")
        expect(start_button).to be_present
      end

      it "共有カテゴリの中にあるユーザーの非公開の定型文は出ない" do
        create(:flow_item, message_category: shared_category, user: other_user, icon_color: "gray", name: "他人の秘密の定型文")

        get message_category_blink_scan_path(shared_category)

        expect(response.body).not_to include("他人の秘密の定型文")
        expect(scan_items.map(&:first)).to eq([ shared_item.key, "scan:pause" ])
      end

      it "ユーザーが作ったカテゴリは 404" do
        category = create(:message_category, user: other_user, icon_color: "gray")

        get message_category_blink_scan_path(category)

        expect(response).to have_http_status(:not_found)
      end

      it "存在しないカテゴリは 404" do
        get message_category_blink_scan_path(message_category_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "ログイン中のユーザーの場合" do
      before { sign_in user }

      it "共有カテゴリでは、共有の定型文と自分の定型文だけが並ぶ（他人の非公開は出ない）" do
        own = create(:flow_item, message_category: shared_category, user: user, icon_color: "gray", name: "自分の定型文", position: 2)
        create(:flow_item, message_category: shared_category, user: other_user, icon_color: "gray", name: "他人の秘密の定型文", position: 3)

        get message_category_blink_scan_path(shared_category)

        expect(response).to have_http_status(:ok)
        expect(scan_items.map(&:first)).to eq([ shared_item.key, own.key, "scan:pause" ])
        expect(response.body).not_to include("他人の秘密の定型文")
      end

      it "自分のカテゴリは開ける" do
        category = create(:message_category, user: user, icon_color: "gray")
        item = create(:flow_item, message_category: category, user: user, icon_color: "gray")

        get message_category_blink_scan_path(category)

        expect(response).to have_http_status(:ok)
        expect(scan_items.map(&:first)).to eq([ item.key, "scan:pause" ])
      end

      it "他人のカテゴリは 404" do
        category = create(:message_category, user: other_user, icon_color: "gray")
        create(:flow_item, message_category: category, user: other_user, icon_color: "gray")

        get message_category_blink_scan_path(category)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "並び順" do
      it "position の順、同じ position なら作った順（id の順）に固定する" do
        third = create(:flow_item, message_category: shared_category, user: nil, position: 5)
        fourth = create(:flow_item, message_category: shared_category, user: nil, position: 5)
        first = create(:flow_item, message_category: shared_category, user: nil, position: 0)

        get message_category_blink_scan_path(shared_category)

        expect(scan_items.map(&:first)).to eq([ first.key, shared_item.key, third.key, fourth.key, "scan:pause" ])
      end
    end

    describe "定型文が 0 件のカテゴリ" do
      it "始められない（その旨を出し、開始ボタンもスキャン項目も出さない）" do
        empty_category = create(:message_category, user: nil)

        get message_category_blink_scan_path(empty_category)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("blink_scans.show.empty"))
        expect(start_button).to be_nil
        expect(scan_items).to be_empty
        expect(page.at_css("[data-controller~='scan']")).to be_nil
      end

      it "ゲストから見て 0 件（ユーザーの非公開の定型文しか無い共有カテゴリ）でも、始められない" do
        category = create(:message_category, user: nil)
        create(:flow_item, message_category: category, user: other_user, icon_color: "gray")

        get message_category_blink_scan_path(category)

        expect(response.body).to include(I18n.t("blink_scans.show.empty"))
        expect(start_button).to be_nil
      end
    end

    describe "定型文が多い時（介助者向けのお知らせ）" do
      def notice
        I18n.t("blink_scans.show.too_many", count: 11)
      end

      it "10 個までは何も出さない" do
        create_list(:flow_item, 9, message_category: shared_category, user: nil)

        get message_category_blink_scan_path(shared_category)

        expect(scan_items.size).to eq(11)
        expect(response.body).not_to include(I18n.t("blink_scans.show.too_many", count: 10))
      end

      it "10 個を超えたら、絞るか分けることをすすめる" do
        create_list(:flow_item, 10, message_category: shared_category, user: nil)

        get message_category_blink_scan_path(shared_category)

        expect(response.body).to include(notice)
        expect(start_button).to be_present
      end
    end

    describe "定型文の名前の出し方" do
      it "名前は文字として出す（HTML として解釈させない）" do
        shared_item.update!(name: "<script>alert(1)</script>")

        get message_category_blink_scan_path(shared_category)

        expect(response.body).not_to include("<script>alert(1)</script>")
        expect(scan_items.first).to eq([ shared_item.key, "<script>alert(1)</script>" ])
      end

      it "長い名前は一覧では 2 行までで切り、確認で出す全文は別に持つ" do
        long_name = "とてもながいていけいぶん" * 10
        shared_item.update!(name: long_name)

        get message_category_blink_scan_path(shared_category)

        item = page.at_css("[data-key='#{shared_item.key}']")
        expect(item["data-name"]).to eq(long_name)
        expect(item.at_css(".line-clamp-2").text.strip).to eq(long_name)
      end
    end

    describe "記録の送り先" do
      it "画面は POST /message_logs へ送る" do
        get message_category_blink_scan_path(shared_category)

        expect(page.at_css("[data-controller~='scan']")["data-scan-url-value"]).to eq(message_logs_path)
      end
    end

    describe "この画面の URL を外に渡さない・残さない" do
      before { get message_category_blink_scan_path(shared_category) }

      it "Referrer-Policy: no-referrer（出た先に、前にいたページとしてこの URL を渡さない）" do
        expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
      end

      it "Cache-Control: no-store" do
        expect(response.headers["Cache-Control"]).to eq("no-store")
      end
    end

    describe "Turbo を使わない（出る時は必ずページを読み込み直す）" do
      it "画面全体に data-turbo=false が付き、turbo-visit-control が reload になっている" do
        get message_category_blink_scan_path(shared_category)

        expect(page.at_css("body")["data-turbo"]).to eq("false")
        expect(page.at_css("meta[name='turbo-visit-control']")["content"]).to eq("reload")
        expect(page.css("body a[href]")).not_to be_empty
        expect(page.css("body a[href]")).to all(satisfy { |link| link.ancestors("[data-turbo='false']").any? })
      end

      it "ふつうの画面（定型文一覧）には付かない" do
        get message_category_flow_items_path(shared_category)

        expect(page.at_css("body")["data-turbo"]).to be_nil
        expect(page.at_css("meta[name='turbo-visit-control']")).to be_nil
      end
    end

    # GA のタグは「本番で、計測 ID がある時」だけ出る。テスト環境のままでは、どの画面にも出ないので比べられない。
    # ここだけ本番のふりをしてダミーの ID を入れ、「ふつうの画面には出て、スキャン画面には出ない」を比べる。
    describe "GA（アクセス解析）を出さない" do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        stub_const("ENV", ENV.to_h.merge("GA_MEASUREMENT_ID" => "G-DUMMY12345"))
      end

      it "ふつうの画面（定型文一覧）には GA のタグが出る" do
        get message_category_flow_items_path(shared_category)

        expect(response.body).to include("googletagmanager.com/gtag/js?id=G-DUMMY12345")
      end

      it "スキャン画面には GA のタグも計測 ID も出ない" do
        get message_category_blink_scan_path(shared_category)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("googletagmanager")
        expect(response.body).not_to include("gtag")
        expect(response.body).not_to include("G-DUMMY12345")
      end
    end
  end

  # 入口のリンクは PR3c で足す。それまでは、どの画面からもスキャン画面へ行けない。
  describe "入口のリンクが無い" do
    let(:blink_scan_url) { message_category_blink_scan_path(shared_category) }

    def expect_no_entry_link(path)
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("blink_scan")
    end

    it "ゲストが見る画面（トップ・カテゴリ一覧・定型文一覧・確認・完了・使い方）のどこにも無い" do
      [
        root_path,
        message_categories_path,
        message_category_flow_items_path(shared_category),
        confirm_message_category_flow_item_path(shared_category, shared_item),
        message_completion_path,
        guide_path
      ].each { |path| expect_no_entry_link(path) }
    end

    it "ログイン中に見る画面（カテゴリ一覧・定型文一覧・確認・完了・記録一覧・設定）のどこにも無い" do
      sign_in user
      create(:flow_item, message_category: shared_category, user: user, icon_color: "gray")

      [
        message_categories_path,
        message_category_flow_items_path(shared_category),
        confirm_message_category_flow_item_path(shared_category, shared_item),
        message_completion_path,
        message_logs_path,
        settings_path
      ].each { |path| expect_no_entry_link(path) }
    end
  end
end
