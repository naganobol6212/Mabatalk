require 'rails_helper'

RSpec.describe Feedback do
  describe 'バリデーション' do
    it 'category と body があれば有効' do
      feedback = build(:feedback)
      expect(feedback).to be_valid
    end

    it 'user がなくても有効（匿名送信OK）' do
      feedback = build(:feedback, user: nil)
      expect(feedback).to be_valid
    end

    context 'body が空の場合' do
      it '無効' do
        feedback = build(:feedback, body: '')
        expect(feedback).not_to be_valid
        expect(feedback.errors[:body]).to be_present
      end
    end

    context 'body が上限文字数を超える場合' do
      it '無効' do
        feedback = build(:feedback, body: 'あ' * (Feedback::BODY_MAX_LENGTH + 1))
        expect(feedback).not_to be_valid
        expect(feedback.errors[:body]).to be_present
      end
    end

    context 'body が上限文字数ちょうどの場合' do
      it '有効' do
        feedback = build(:feedback, body: 'あ' * Feedback::BODY_MAX_LENGTH)
        expect(feedback).to be_valid
      end
    end

    context 'category が指定されていない場合' do
      it '無効' do
        feedback = build(:feedback, category: nil)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:category]).to be_present
      end
    end
  end

  describe 'enum :category' do
    it '3種類のカテゴリを持つ' do
      expect(described_class.categories).to eq('bug' => 0, 'request' => 1, 'other' => 2)
    end

    it 'シンボルでセットできる' do
      feedback = build(:feedback, category: :bug)
      expect(feedback.bug?).to be true
    end
  end

  describe '#category_label' do
    it 'bug の場合 "バグ報告" を返す' do
      feedback = build(:feedback, category: :bug)
      expect(feedback.category_label).to eq('バグ報告')
    end

    it 'request の場合 "機能要望" を返す' do
      feedback = build(:feedback, category: :request)
      expect(feedback.category_label).to eq('機能要望')
    end

    it 'other の場合 "その他" を返す' do
      feedback = build(:feedback, category: :other)
      expect(feedback.category_label).to eq('その他')
    end
  end

  describe 'screenshots バリデーション' do
    let(:png_path) { Rails.root.join('spec/fixtures/files/sample.png') }

    before do
      FileUtils.mkdir_p(File.dirname(png_path))
      File.binwrite(png_path, "\x89PNG\r\n\x1a\n" + "\x00" * 100) unless File.exist?(png_path)
    end

    context '添付なしの場合' do
      it '有効' do
        feedback = build(:feedback)
        expect(feedback).to be_valid
      end
    end

    context '上限枚数を超える場合' do
      it '無効' do
        feedback = build(:feedback)
        (Feedback::MAX_SCREENSHOTS + 1).times do
          feedback.screenshots.attach(io: File.open(png_path), filename: 'sample.png', content_type: 'image/png')
        end
        expect(feedback).not_to be_valid
        expect(feedback.errors[:screenshots]).to be_present
      end
    end

    context '許可されていない content_type の場合' do
      it '無効' do
        feedback = build(:feedback)
        feedback.screenshots.attach(io: StringIO.new('dummy'), filename: 'evil.exe', content_type: 'application/octet-stream')
        expect(feedback).not_to be_valid
        expect(feedback.errors[:screenshots]).to be_present
      end
    end

    context 'content_type は許可されているが拡張子が許可外の場合' do
      it '無効' do
        feedback = build(:feedback)
        feedback.screenshots.attach(io: StringIO.new('dummy'), filename: 'evil.exe', content_type: 'image/png')
        expect(feedback).not_to be_valid
        expect(feedback.errors[:screenshots]).to be_present
      end
    end

    context 'サイズが上限を超える場合' do
      it '無効' do
        feedback = build(:feedback)
        oversized_data = "\x89PNG\r\n\x1a\n" + "\x00" * (Feedback::MAX_SCREENSHOT_SIZE + 1)
        feedback.screenshots.attach(io: StringIO.new(oversized_data), filename: 'big.png', content_type: 'image/png')
        expect(feedback).not_to be_valid
        expect(feedback.errors[:screenshots]).to be_present
      end
    end
  end
end
