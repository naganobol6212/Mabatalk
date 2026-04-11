require 'rails_helper'

RSpec.describe DetailFlowCompletionService do
  let(:user) { create(:user) }
  let(:flow_item) { create(:flow_item) }
  let(:steps) do
    [
      { key: "temperature", label: "体温" },
      { key: "meal",        label: "食事" }
    ]
  end
  let(:answers) do
    {
      "temperature" => { "value" => "normal", "label" => "平熱" },
      "meal"        => { "value" => "all",    "label" => "完食" }
    }
  end

  describe '.call' do
    context '全stepに回答がある場合' do
      it 'MessageLog が1件作成される' do
        expect {
          DetailFlowCompletionService.call(
            user: user,
            flow_item: flow_item,
            steps: steps,
            answers: answers
          )
        }.to change(MessageLog, :count).by(1)
      end

      it 'detail_flow_text にステップのラベルと回答が含まれる' do
        log = DetailFlowCompletionService.call(
          user: user,
          flow_item: flow_item,
          steps: steps,
          answers: answers
        )
        expect(log.detail_flow_text).to eq("体温：平熱、食事：完食")
      end

      it 'detail_flow_data に answers が保存される' do
        log = DetailFlowCompletionService.call(
          user: user,
          flow_item: flow_item,
          steps: steps,
          answers: answers
        )
        expect(log.detail_flow_data).to eq(answers)
      end
    end

    context 'answers に steps に存在しないキーが含まれる場合' do
      let(:answers_with_unknown_key) do
        answers.merge("unknown_key" => { "value" => "xxx", "label" => "不明" })
      end

      it '不正なキーを除外して MessageLog が作成される' do
        log = DetailFlowCompletionService.call(
          user: user,
          flow_item: flow_item,
          steps: steps,
          answers: answers_with_unknown_key
        )
        expect(log.detail_flow_data.key?("unknown_key")).to be false
      end

      it 'detail_flow_text に不正なキーの内容が含まれない' do
        log = DetailFlowCompletionService.call(
          user: user,
          flow_item: flow_item,
          steps: steps,
          answers: answers_with_unknown_key
        )
        expect(log.detail_flow_text).not_to include("不明")
      end
    end
  end
end
