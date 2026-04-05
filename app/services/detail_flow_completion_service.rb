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
    parts = @steps.filter_map do |step|
      ans = @answers[step[:key]]
      next unless ans
      "#{step[:label]}：#{ans['label']}"
    end
    MessageLog.create!(
      user: @user,
      flow_item: @flow_item,
      detail_flow_text: parts.join("、").presence,
      detail_flow_data: @answers.presence
    )
  end
end
