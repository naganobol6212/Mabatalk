  class CreateAiSummaries < ActiveRecord::Migration[7.2]
    def up
      create_table :ai_summaries do |t|
        t.references :user, null: false, foreign_key: true, index: { unique: true }
        t.text :content, null: false
        t.datetime :generated_at, null: false
        t.timestamps
      end
      # NOTE: 将来「月次履歴保存」に変える場合は設計ごと変更する。
      #       今は「1ユーザー1要約（上書き型）」仕様に準拠。
    end

    def down
      drop_table :ai_summaries
    end
  end
