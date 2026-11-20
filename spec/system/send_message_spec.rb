require 'rails_helper'

# 利用者のいちばん大事な一連の操作を、本物のブラウザ（ヘッドレス Chrome）で通す。
# ログイン → カテゴリを選ぶ → 項目を選ぶ → 「はい」で伝える → 完了画面 → ログに残る
RSpec.describe "ログインしてメッセージを伝える", type: :system do
  before { driven_by :selenium_chrome_headless }

  it "ログインからカテゴリ・項目の選択、完了、ログ表示まで通る" do
    user = create(:user, email: "taro@example.com", password: "password123")
    category = create(:message_category, user: nil, name: "のみもの", kana: "のみもの")
    create(:flow_item, message_category: category, user: nil, name: "おちゃ", kana: "おちゃ")

    visit new_user_session_path
    fill_in "user[email]", with: "taro@example.com"
    fill_in "user[password]", with: "password123"
    click_button "ログイン", exact: true

    expect(page).to have_current_path(message_categories_path)
    click_link "のみもの"

    expect(page).to have_current_path(message_category_flow_items_path(category))
    click_link "おちゃ"

    expect(page).to have_content("おちゃ")
    click_button "はい"

    expect(page).to have_current_path(message_completion_path)
    expect(page).to have_content("おちゃ")
    expect(page).to have_content(I18n.t("message_logs.created"))

    visit message_logs_path
    expect(page).to have_content("おちゃ")
    expect(user.message_logs.count).to eq(1)
  end
end
