# ログイン状態を「利用者から見える振る舞い」で確かめるためのヘルパー。
# 設定画面はログイン必須なので、開ければログイン中、ログイン画面へ飛ばされれば未ログイン。
module LoginStateHelpers
  def expect_logged_in
    get settings_path
    expect(response).to have_http_status(:ok)
  end

  def expect_logged_out
    get settings_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

RSpec.configure do |config|
  config.include LoginStateHelpers, type: :request
end
