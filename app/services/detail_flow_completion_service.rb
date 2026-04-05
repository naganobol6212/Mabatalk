class DetailFlowCompletionService
  def self.call(user:, flow_item:, steps:, answers:)
    new(user:, flow_item:, steps:, answers:).call
  end

  def initialize(user:, flow_item:, steps:, answers:)
    @user = user
    @flow_item = flow_item
    @steps = steps
    @answers = answers
  end

  def call
    allowed_keys = @steps.map { |step| step[:key] }
    filtered_answers = @answers.slice(*allowed_keys)

    parts = @steps.filter_map do |step|
      ans = filtered_answers[step[:key]]
      next unless ans
      "#{step[:label]}：#{ans['label']}"
    end
    MessageLog.create!(
      user: @user,
      flow_item: @flow_item,
      detail_flow_text: parts.join("、").presence,
      detail_flow_data: filtered_answers.presence
    )
  end
end
