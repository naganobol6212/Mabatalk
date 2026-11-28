require "capybara/selenium/driver"

# Chrome 158 から、Capybara 3.40.0 が後片付け（reset!）で送る
# `Storage.clearDataForOrigin`（origin: "*"）が「* is not a valid URL」と拒否され、
# テストの本体が通っていても、system spec がすべて後片付けで落ちる。
# 拒否された時だけ、Cookie をすべて消す命令（Network.clearBrowserCookies）に切り替えて、
# 前のテストのログインが次のテストに残らないようにする。
# 古い Chrome では拒否されないので、今までどおり Capybara の後片付けがそのまま動く。
#
# 限界: 切り替えた時に消すのは Cookie だけ。localStorage は消さない（このアプリは使っていない）。
# Capybara がこの問題を直した版を出したら、このファイルと、system spec の require を消す。
module ChromeResetFallback
  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetFallback)
