require 'rails_helper'

RSpec.describe AiSummaryService do
  let(:user) { create(:user) }

  def stub_anthropic(text: "テスト要約")
    allow_any_instance_of(Anthropic::Client).to receive_message_chain(:messages, :create)
      .and_return(double(content: [double(text: text)]))
  end

  describe ".call" do
    context "ログが1件もない場合" do
      it "空の集計でも正常終了して要約テキストを返す" do
        stub_anthropic(text: "ログがありません")
        result = AiSummaryService.call(user: user)
        expect(result).to eq("ログがありません")
      end
    end

    context "ログがある場合" do
      before do
        category = create(:message_category, user: nil, name: "飲み物")
        flow_item = create(:flow_item, message_category: category, user: nil, name: "お茶")
        3.times { create(:message_log, user: user, flow_item: flow_item) }
      end

      it "要約テキストを返す" do
        stub_anthropic(text: "お茶をよく選んでいます")
        result = AiSummaryService.call(user: user)
        expect(result).to eq("お茶をよく選んでいます")
      end

      it "Anthropic::Client に正しいモデルでリクエストを送る" do
        client_double = instance_double(Anthropic::Client)
        messages_double = double("messages")
        allow(Anthropic::Client).to receive(:new).and_return(client_double)
        allow(client_double).to receive(:messages).and_return(messages_double)
        allow(messages_double).to receive(:create)
          .and_return(double(content: [double(text: "要約")]))

        AiSummaryService.call(user: user)

        expect(messages_double).to have_received(:create).with(
          hash_including(model: AiSummaryService::MODEL)
        )
      end
    end

    context "API タイムアウトが発生した場合" do
      it "Anthropic::Errors::APITimeoutError が伝播する" do
        allow_any_instance_of(Anthropic::Client).to receive_message_chain(:messages, :create)
          .and_raise(Anthropic::Errors::APITimeoutError.new(url: "https://api.anthropic.com"))
        expect {
          AiSummaryService.call(user: user)
        }.to raise_error(Anthropic::Errors::APITimeoutError)
      end
    end
  end
end
