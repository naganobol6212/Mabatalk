class AiSummaryService
  LOOKBACK_DAYS = 30
  MAX_TOKENS = 600
  MODEL = "claude-haiku-4-5-20251001"
  SYSTEM_PROMPT = <<~PROMPT.freeze
    あなたは、重度障害のある方のコミュニケーション支援アプリの
    ログを振り返るためのアシスタントです。

    このアプリでは、本人がまばたきで選択肢を選ぶことで
    意思表示を行います。ログは「本人が実際に選んだ項目」の記録です。

    この要約は、介護スタッフおよび家族が振り返りや
    ケアの参考にするための補助情報です。

    以下を厳守してください：
    - 医療的診断や断定的表現は行わない
    - ログから読み取れる事実を中心に述べる
    - ログに含まれていない情報を推測して補完しない
    - 頻度の高い項目を優先して述べ、少数の項目を過度に強調しない
    - 推測は「〜かもしれません」程度にとどめる
    - マークダウン記法（# 、** 、* など）は使用しない
    - 温かみのある落ち着いた文体で書く

    次の形式で、各セクション1〜2文、合計200〜300文字でまとめてください：

    【よく伝えていたこと】
    （この期間に多かった意思表示やニーズ）

    【気になるパターン】
    （繰り返し見られる傾向があれば）

    【ケアへの気づき】
    （環境づくりや関わり方のヒント）
  PROMPT

  def self.call(user:)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    logs = @user.message_logs
                .where(created_at: LOOKBACK_DAYS.days.ago..)
                .order(created_at: :desc)
    stats = build_stats(logs)
    prompt = build_prompt(stats, logs.size)
    generate_summary(prompt)
  end

  private

  def build_stats(logs)
    logs.group_by(&:message_category_name)
        .transform_values { |cat_logs|
          cat_logs.group_by(&:flow_item_name).transform_values(&:count)
        }
  end

  def build_prompt(stats, total)
    lines = [ "直近30日のコミュニケーション記録（合計 #{total} 件）\n" ]
    stats.each do |cat, items|
      lines << "[#{cat}]"
      items.sort_by { |_, count| -count }
            .each { |item, count| lines << "  - #{item}: #{count}件" }
    end
    lines.join("\n")
  end

  def generate_summary(prompt)
    client = Anthropic::Client.new(api_key: Rails.application.credentials.dig(:anthropic, :api_key))
    response = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ]
    )
    response.content.first.text
  end
end
