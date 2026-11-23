require 'rails_helper'

# まばたきスキャン画面を、本物のブラウザ（ヘッドレス Chrome）で通す。
# PR2 の入力はキー操作: 光っている時に Space / Enter を押すと「長いまばたき 1 回」と同じ扱いになる。
# 時間は画面の data 属性（data-scan-settings-value）で短くするが、表示の切り替わりは待つ（sleep に頼らない）。
RSpec.describe "まばたきスキャン画面で選んで伝える", type: :system do
  before { driven_by :selenium_chrome_headless }

  # 1 項目 1200ms（先頭は 1.5 倍の 1800ms）、安定待ち 150ms、完了表示 1000ms
  FAST_SETTINGS = { stepMs: 1200, refractoryMs: 150, doneMs: 1000 }.freeze

  let(:category) { create(:message_category, user: nil, name: "のみもの", kana: "のみもの") }
  let!(:tea) { create(:flow_item, message_category: category, user: nil, name: "おちゃ", kana: "おちゃ", position: 1) }
  let!(:water) { create(:flow_item, message_category: category, user: nil, name: "みず", kana: "みず", position: 2) }

  def t(key, **options)
    I18n.t("blink_scans.show.#{key}", **options)
  end

  def log_in(user)
    visit new_user_session_path
    fill_in "user[email]", with: user.email
    fill_in "user[password]", with: "password123"
    click_button "ログイン", exact: true
    expect(page).to have_current_path(message_categories_path)
  end

  def open_scan(settings = FAST_SETTINGS)
    visit message_category_blink_scan_path(category)
    page.execute_script(<<~JS, settings.to_json)
      document.querySelector("[data-controller~='scan']").setAttribute("data-scan-settings-value", arguments[0])
    JS
    watch_highlights
  end

  def start_scan(settings = FAST_SETTINGS)
    open_scan(settings)
    click_button t("start")
  end

  # 光り始めるたびに、その項目（確認の時は質問の文も）が画面の中に見えていたかを控える。
  # 見えている = 表示領域からはみ出さず、上のヘッダー・下のメニュー（固定表示）にも隠れていない
  def watch_highlights
    page.execute_script(<<~JS)
      const visible = (element) => {
        const box = element.getBoundingClientRect()
        if (box.top < 0 || box.left < 0 || box.bottom > window.innerHeight || box.right > window.innerWidth) return false
        const middle = [(box.left + box.right) / 2, (box.top + box.bottom) / 2]
        const corners = [[box.left + 4, box.top + 4], [box.right - 4, box.top + 4], [box.left + 4, box.bottom - 4], [box.right - 4, box.bottom - 4]]
        return [middle, ...corners].every(([x, y]) => element.contains(document.elementFromPoint(x, y)))
      }
      const scan = document.querySelector("[data-controller~='scan']")
      window.scanWatch = { seen: {}, questionSeen: [] }
      new MutationObserver((changes) => {
        for (const { target } of changes) {
          if (!target.hasAttribute("data-highlighted")) continue
          const key = target.dataset.key
          window.scanWatch.seen[key] = (window.scanWatch.seen[key] || []).concat(visible(target))
          if (key.startsWith("confirm:")) {
            const question = scan.querySelector("[data-screens='confirming'] [data-scan-target='pendingName']").parentElement
            window.scanWatch.questionSeen.push(visible(question))
          }
        }
      }).observe(scan, { attributes: true, attributeFilter: ["data-highlighted"], subtree: true })
    JS
  end

  # 光った項目ごとの「見えていたか」。{ key => [true, ...] }
  def seen_highlights
    page.evaluate_script("window.scanWatch.seen")
  end

  # keys がすべて 1 回は光るまで待つ（Capybara の待ち方: 条件が成り立つまで確かめ直す）
  def wait_until_highlighted_once(keys)
    page.document.synchronize(20, errors: [ Capybara::ExpectationNotMet ]) do
      missing = keys - seen_highlights.keys
      raise Capybara::ExpectationNotMet, "まだ光っていない: #{missing.join(', ')}" if missing.any?
    end
  end

  # スマホを縦に持った大きさ（375×667）で見る
  def on_phone_screen
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 667, deviceScaleFactor: 2, mobile: false)
    yield
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def highlighted(key)
    "[data-key='#{key}'][data-highlighted]"
  end

  # いまフォーカスがある所へキーを送る（利用者がキーボードを押すのと同じ）
  def press(key = :space)
    page.driver.browser.action.send_keys(key).perform
  end

  # その項目が光るのを待って押す
  def select_when_highlighted(key, with: :space)
    expect(page).to have_css(highlighted(key), wait: 20)
    press(with)
  end

  def choose_tea_and_wait_for_yes
    select_when_highlighted(tea.key)
    expect(page).to have_content(t("confirm_question_html", name: "おちゃ"))
    expect(page).to have_css(highlighted("confirm:yes"), wait: 10)
  end

  # 1 回目の送信だけ「サーバーには届いて保存されたが、返事はまだ届いていない」ことにする。
  # 返事は deliver_held_response を呼ぶまで渡さない（打ち切られても渡す = 遅れて届いた返事）。送った送信ID は控える
  def hold_first_response
    page.execute_script(<<~JS)
      const realFetch = window.fetch.bind(window)
      window.sentSubmissionIds = []
      window.fetch = (url, options) => {
        window.sentSubmissionIds.push(JSON.parse(options.body).submission_id)
        const { signal, ...withoutSignal } = options
        if (window.sentSubmissionIds.length > 1) return realFetch(url, options)
        const answered = realFetch(url, withoutSignal).then(async (res) => {
          const body = await res.json()
          return { status: res.status, json: async () => body }
        })
        window.firstRequestAnswered = answered
        return new Promise((resolve) => {
          window.deliverHeldResponse = () => answered.then(resolve)
        })
      }
    JS
  end

  # サーバーが 1 回目の送信に答え終わる（= 保存が終わる）まで待つ
  def wait_until_first_request_is_answered
    page.evaluate_async_script("window.firstRequestAnswered.then(() => arguments[0]())")
  end

  # 止めておいた返事を画面に渡し、画面がそれを受け取り終わるまで待つ
  def deliver_held_response
    page.evaluate_async_script("window.deliverHeldResponse().then(() => setTimeout(arguments[0], 0))")
  end

  it "ゲスト: Space で選ぶ → 確認 → 「はい」→ 完了 → スキャンに戻る。記録は増えず、履歴に残らないと出る" do
    start_scan

    select_when_highlighted(tea.key)
    expect(page).to have_content(t("confirm_question_html", name: "おちゃ"))
    # 確認は「いいえ」から光り、そのあと「はい」が光る
    expect(page).to have_css(highlighted("confirm:no"), wait: 10)
    select_when_highlighted("confirm:yes")

    expect(page).to have_content(t("done_html", name: "おちゃ"), wait: 10)
    expect(page).to have_content(t("guest_note"))
    # 完了表示のあと、自動でスキャンの先頭に戻る
    expect(page).to have_css(highlighted(tea.key), wait: 10)
    expect(page).to have_no_content(t("done_html", name: "おちゃ"))
    expect(MessageLog.count).to eq(0)
  end

  it "ログイン中: Enter でも選べる。「はい」で記録が 1 件でき、履歴に残らないという注意は出ない" do
    user = create(:user, email: "taro@example.com", password: "password123")
    log_in(user)
    start_scan

    # 2 番目の「みず」が光るまで待って選ぶ
    select_when_highlighted(water.key, with: :enter)
    expect(page).to have_content(t("confirm_question_html", name: "みず"))
    select_when_highlighted("confirm:yes", with: :enter)

    expect(page).to have_content(t("done_html", name: "みず"), wait: 10)
    expect(page).to have_no_content(t("guest_note"))
    expect(page).to have_css(highlighted(tea.key), wait: 10)

    log = user.message_logs.sole
    expect(log.flow_item_name).to eq("みず")
    expect(log.submission_id).to match(MessageLog::SUBMISSION_ID_FORMAT)
  end

  it "「いいえ」で押すと、送らずにスキャンへ戻る" do
    user = create(:user, email: "taro@example.com", password: "password123")
    log_in(user)
    start_scan

    select_when_highlighted(tea.key)
    select_when_highlighted("confirm:no")

    expect(page).to have_css(highlighted(tea.key), wait: 10)
    expect(page).to have_no_content(t("confirm_question_html", name: "おちゃ"))
    expect(page).to have_no_content(t("done_html", name: "おちゃ"))
    expect(user.message_logs.count).to eq(0)
  end

  it "タップでも選べる（キーと同じ選択処理に入る）" do
    start_scan

    expect(page).to have_css(highlighted(tea.key), wait: 10)
    find(highlighted(tea.key)).click
    expect(page).to have_content(t("confirm_question_html", name: "おちゃ"))
    expect(page).to have_css(highlighted("confirm:yes"), wait: 10)
    find(highlighted("confirm:yes")).click

    expect(page).to have_content(t("done_html", name: "おちゃ"), wait: 10)
  end

  it "押しっぱなし（キーのくり返し）は 1 回として扱う。確認の「いいえ」が光っても、くり返しでは選ばれない" do
    start_scan

    select_when_highlighted(tea.key)
    expect(page).to have_css(highlighted("confirm:no"), wait: 10)
    # 押したままの時にブラウザが出し続ける keydown（repeat: true）を、フォーカスのある所へ流す
    page.execute_script(<<~JS)
      for (let i = 0; i < 5; i++) {
        document.activeElement.dispatchEvent(new KeyboardEvent("keydown", { key: " ", code: "Space", repeat: true, bubbles: true, cancelable: true }))
      }
    JS

    # 「いいえ」が選ばれていれば確認が消えてスキャンに戻る。選ばれていないので、そのまま「はい」が光る
    expect(page).to have_css(highlighted("confirm:yes"), wait: 10)
    expect(page).to have_content(t("confirm_question_html", name: "おちゃ"))
  end

  it "「停止」ボタンにフォーカスがある時の Space は、スキャン入力にならず、ボタンがふつうに押される" do
    start_scan

    expect(page).to have_css(highlighted(tea.key), wait: 10)
    find_button(t("stop")).send_keys(:space)

    expect(page).to have_button(t("start"))
    expect(page).to have_no_button(t("stop"))
    expect(page).to have_no_content(t("confirm_question_html", name: "おちゃ"))
    expect(page).to have_no_css("[data-highlighted]")
  end

  it "Shift を押しながらの Space は、スキャン入力にならない（何も選ばれない）" do
    start_scan

    expect(page).to have_css(highlighted(tea.key), wait: 10)
    page.driver.browser.action.key_down(:shift).send_keys(:space).key_up(:shift).perform

    # 選ばれていれば、押した時点で確認に入っている。選ばれていないので確認は出ず、そのまま次の定型文が光る
    expect(page).to have_no_content(t("confirm_question_html", name: "おちゃ"), wait: 0)
    expect(page).to have_css(highlighted(water.key), wait: 10)
  end

  it "「開始」を押す前は、Space を押しても何も選ばれない" do
    open_scan

    press
    expect(page).to have_button(t("start"))
    expect(page).to have_no_css("[data-highlighted]")
    expect(page).to have_no_content(t("confirm_question_html", name: "おちゃ"))
  end

  it "出口（定型文一覧へ戻る）は、Turbo を使わずページを読み込み直す" do
    start_scan
    expect(page).to have_css(highlighted(tea.key), wait: 10)
    # 読み込み直されれば消える目印を window に付けておく（Turbo の画面切り替えでは window が残る）
    page.execute_script("window.scanPageMarker = true")

    click_link t("back_to_list")

    expect(page).to have_current_path(message_category_flow_items_path(category))
    expect(page).to have_link("おちゃ")
    expect(page.evaluate_script("window.scanPageMarker")).to be_nil
  end

  it "ヘッダーの戻るリンクから出る時も、ページを読み込み直す" do
    start_scan
    page.execute_script("window.scanPageMarker = true")

    find("header a[href='#{message_category_flow_items_path(category)}']").click

    expect(page).to have_current_path(message_category_flow_items_path(category))
    expect(page).to have_link("おちゃ")
    expect(page.evaluate_script("window.scanPageMarker")).to be_nil
  end

  it "「はい」が光っている時に画面を離れて戻ると、先頭からやり直し、前の「はい」の候補で送らない" do
    user = create(:user, email: "taro@example.com", password: "password123")
    log_in(user)
    start_scan
    choose_tea_and_wait_for_yes

    page.execute_script('window.dispatchEvent(new PageTransitionEvent("pagehide"))')
    expect(page).to have_no_css("[data-highlighted]")
    press
    page.execute_script('window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true }))')

    expect(page).to have_css(highlighted(tea.key), wait: 10)
    expect(page).to have_no_content(t("done_html", name: "おちゃ"))
    expect(user.message_logs.count).to eq(0)
  end

  describe "スマホの縦の画面（375×667）で、定型文が 10 個ある時" do
    let!(:more_items) do
      (3..10).map { |n| create(:flow_item, message_category: category, user: nil, name: "ことば#{n}", kana: "ことば#{n}", position: n) }
    end
    let(:all_keys) { [ tea.key, water.key, *more_items.map(&:key), "scan:pause" ] }

    it "下の段の定型文・「休止」が光る時も、光っている項目は画面の中に見えている" do
      on_phone_screen do
        # 押さずに 1 周見るだけなので、1 項目の時間は短くする
        start_scan(FAST_SETTINGS.merge(stepMs: 250))
        expect(page.evaluate_script("[window.innerWidth, window.innerHeight]")).to eq([ 375, 667 ])

        wait_until_highlighted_once(all_keys)

        hidden = seen_highlights.reject { |_key, seen| seen.all? }.keys
        expect(hidden).to eq([])
      end
    end

    it "いちばん下の定型文を選んだあとの確認でも、質問の文（何を伝えるか）と光っている「いいえ」「はい」が見えている" do
      on_phone_screen do
        start_scan

        select_when_highlighted(more_items.last.key)
        expect(page).to have_content(t("confirm_question_html", name: "ことば10"))
        wait_until_highlighted_once([ "confirm:no", "confirm:yes" ])

        expect(seen_highlights.slice("confirm:no", "confirm:yes").values.flatten).to all(be(true))
        expect(page.evaluate_script("window.scanWatch.questionSeen")).to all(be(true)).and(be_present)
      end
    end
  end

  describe "送信がうまくいかなかった時" do
    it "定型文が消されていた（404）: 介助者を呼ぶ表示で止まり、そのあと押しても動かない" do
      start_scan
      choose_tea_and_wait_for_yes
      tea.destroy!
      press

      expect(page).to have_content(t("halted.title"), wait: 10)
      expect(page).to have_content(t("halted.not_found"))
      expect(page).to have_button(t("halted.reload_button"))
      press
      expect(page).to have_no_css("[data-highlighted]")
      expect(page).to have_no_content(t("done_html", name: "おちゃ"))
    end

    it "保存はできたのに返事が届かなかった: 「届いたか確認できません」→「もう一度送る」は同じ送信IDで、記録は 1 件だけ" do
      user = create(:user, email: "taro@example.com", password: "password123")
      log_in(user)
      start_scan
      # 1 回目だけ「サーバーには届いて保存されたが、返事が途中で失われた」ことにする。送った送信ID は控えておく
      page.execute_script(<<~JS)
        const realFetch = window.fetch.bind(window)
        window.sentSubmissionIds = []
        window.fetch = async (url, options) => {
          window.sentSubmissionIds.push(JSON.parse(options.body).submission_id)
          const response = await realFetch(url, options)
          if (window.sentSubmissionIds.length === 1) throw new TypeError("返事が届かなかった（テスト）")
          return response
        }
      JS
      choose_tea_and_wait_for_yes
      press

      expect(page).to have_content(t("unknown.title"), wait: 10)
      expect(page).to have_no_content(t("done_html", name: "おちゃ"))
      expect(user.message_logs.count).to eq(1)

      click_button t("unknown.retry")

      expect(page).to have_content(t("done_html", name: "おちゃ"), wait: 10)
      sent = page.evaluate_script("window.sentSubmissionIds")
      expect(sent.size).to eq(2)
      expect(sent.uniq.size).to eq(1)
      expect(user.message_logs.sole.submission_id).to eq(sent.first)
    end

    it "保存はできたが返事が届く前に「停止」→「開始」: スキャンには戻らず「届いたか確認できません」に戻り、「もう一度送る」は同じ送信IDで、記録は 1 件だけ" do
      user = create(:user, email: "taro@example.com", password: "password123")
      log_in(user)
      start_scan
      hold_first_response
      choose_tea_and_wait_for_yes
      press
      expect(page).to have_content(t("sending_html", name: "おちゃ"))
      wait_until_first_request_is_answered
      expect(user.message_logs.count).to eq(1)

      click_button t("stop")
      expect(page).to have_button(t("start"))
      # 止めたあとで返事が届いても、完了表示にはしない
      deliver_held_response
      expect(page).to have_button(t("start"))
      expect(page).to have_no_content(t("done_html", name: "おちゃ"))

      click_button t("start")
      expect(page).to have_content(t("unknown.title"))
      expect(page).to have_content(t("unknown.target_html", name: "おちゃ"))
      expect(page).to have_no_css("[data-highlighted]")

      click_button t("unknown.retry")
      expect(page).to have_content(t("done_html", name: "おちゃ"), wait: 10)
      sent = page.evaluate_script("window.sentSubmissionIds")
      expect(sent.size).to eq(2)
      expect(sent.uniq.size).to eq(1)
      expect(user.message_logs.sole.submission_id).to eq(sent.first)
    end
  end
end
