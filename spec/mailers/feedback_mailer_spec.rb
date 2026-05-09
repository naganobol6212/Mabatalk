require "rails_helper"

RSpec.describe FeedbackMailer, type: :mailer do
  describe "#notify_admin" do
    let(:admin_email) { "admin@example.com" }
    let(:user) { create(:user, email: "tester@example.com") }
    let(:feedback) { create(:feedback, user: user, category: :bug, body: "ボタンが反応しない") }
    let(:mail) { described_class.notify_admin(feedback) }

    before do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:admin, :email).and_return(admin_email)
    end

    it "件名にカテゴリラベルが含まれる" do
      expect(mail.subject).to include("バグ報告")
    end

    it "credentials の管理者メアドに送信される" do
      expect(mail.to).to eq([admin_email])
    end

    it "本文（HTML）に本文と送信者メアドが含まれる" do
      expect(mail.html_part.body.encoded).to include("ボタンが反応しない")
      expect(mail.html_part.body.encoded).to include("tester@example.com")
    end

    it "本文（テキスト）に本文と送信者メアドが含まれる" do
      expect(mail.text_part.body.encoded).to include("ボタンが反応しない")
      expect(mail.text_part.body.encoded).to include("tester@example.com")
    end

    context "匿名送信の場合" do
      let(:feedback) { create(:feedback, user: nil, category: :request, body: "新機能ほしい") }

      it "本文に「匿名」と表示される" do
        expect(mail.html_part.body.encoded).to include("匿名")
        expect(mail.text_part.body.encoded).to include("匿名")
      end
    end
  end
end
