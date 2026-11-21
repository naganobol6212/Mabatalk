# 画面に出ている本物のフォームを読み取り、ブラウザと同じ送信先・メソッド・欄の名前で送るためのヘルパー。
# 送信先や欄の名前をテストに直接書くと、画面のフォームが壊れてもテストが通ってしまうため。
module FormHelpers
  # いま開いている画面から、selector に合う入力欄を持つフォームを取り出す
  def form_containing(selector)
    form = Nokogiri::HTML(response.body).css("form").find { |candidate| candidate.at_css(selector) }
    expect(form).to be_present, "画面に #{selector} を持つフォームがありません"
    form
  end

  # フォームに最初から入っている値（hidden の欄）。ブラウザは送信のときにそのまま送る
  def hidden_fields(form)
    form.css("input[type='hidden']").map { |input| [ input["name"], input["value"].to_s ] }
  end

  # フォームの action / method へ、[欄の名前, 値] の組をブラウザと同じ形で送る。
  # 名前が [] で終わる欄（複数選べる欄）は、同じ名前の値をまとめて配列として送る。
  def submit_form(form, fields)
    params = {}
    fields.each do |name, value|
      if name.end_with?("[]")
        (params[name.delete_suffix("[]")] ||= []) << value
      else
        params[name] = value
      end
    end

    process form["method"].to_sym, form["action"], params: params
  end
end

RSpec.configure do |config|
  config.include FormHelpers, type: :request
end
