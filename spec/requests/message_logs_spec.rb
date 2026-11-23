require 'rails_helper'

RSpec.describe "MessageLogs", type: :request do
  describe "GET /message_logs" do
    context "未認証ユーザーの場合" do
      it "未認証ユーザーはリダイレクトされる" do
        get message_logs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みユーザーの場合" do
      it "自分のログを取得できる" do
        user = create(:user)
        sign_in user
        get message_logs_path
        expect(response).to have_http_status(:ok)
      end

      it "他ユーザーのログが含まれない" do
        user = create(:user)
        other_user = create(:user)
        sign_in user
        my_log = create(:message_log, user: user)
        other_log = create(:message_log, user: other_user)
        get message_logs_path
        expect(response.body).to include(my_log.flow_item_name)
        expect(response.body).not_to include(other_log.flow_item_name)
      end
    end
  end

  describe "POST /message_logs" do
    context "未認証ユーザーの場合" do
      it "MessageLogが作成されない" do
        flow_item = create(:flow_item)
        expect { post message_logs_path,
          params: { flow_item_key: flow_item.key }
        }.not_to change(MessageLog, :count)
      end
    end

    context "認証ユーザーの場合" do
      it "MessageLogが作成される" do
        user = create(:user)
        sign_in user
        flow_item = create(:flow_item)
        expect { post message_logs_path,
          params: { flow_item_key: flow_item.key }
        }.to change(MessageLog, :count)
      end

      it "message_completion_path にリダイレクトされる" do
        user = create(:user)
        sign_in user
        flow_item = create(:flow_item)
        post message_logs_path, params: { flow_item_key: flow_item.key }
        expect(response).to redirect_to(message_completion_path)
      end
    end

    context "未認証ユーザーの場合" do
      it "session[:last_flow_item_key] に flow_item のキーが保存される" do
        flow_item = create(:flow_item)
        post message_logs_path, params: { flow_item_key: flow_item.key }
        expect(session[:last_flow_item_key]).to eq(flow_item.key)
      end
    end

    # 定型文（FlowItem）は「共有（user_id が nil）」か「持ち主本人のもの」だけ使える。
    # 他人の非公開の定型文は、key を知っていても「無いもの」として 404 を返す。
    describe "定型文の公開範囲" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:shared_item) { create(:flow_item, user: nil, name: "共有の定型文") }
      let(:own_item) { create(:flow_item, user: user, icon_color: "gray", name: "自分の定型文") }
      let(:others_private_item) do
        create(:flow_item, user: other_user, icon_color: "gray", name: "他人の秘密の定型文")
      end

      context "ログイン中のユーザーの場合" do
        before { sign_in user }

        it "共有の定型文は記録でき、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: shared_item.key }
          }.to change { user.message_logs.count }.by(1)
          expect(response).to redirect_to(message_completion_path)

          get message_completion_path
          expect(response.body).to include("共有の定型文")
        end

        it "自分の定型文は記録でき、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: own_item.key }
          }.to change { user.message_logs.count }.by(1)
          expect(response).to redirect_to(message_completion_path)

          get message_completion_path
          expect(response.body).to include("自分の定型文")
        end

        it "他人の非公開の定型文は 404 になり、MessageLog が増えない" do
          expect {
            post message_logs_path, params: { flow_item_key: others_private_item.key }
          }.not_to change(MessageLog, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "他人の非公開の定型文の中身が、履歴にも完了画面にも出ない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          get message_logs_path
          expect(response.body).not_to include("他人の秘密の定型文")
          get message_completion_path
          expect(response.body).not_to include("他人の秘密の定型文")
        end

        it "存在しない key は 404 になり、MessageLog が増えない" do
          expect {
            post message_logs_path, params: { flow_item_key: "no-such-key" }
          }.not_to change(MessageLog, :count)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "ゲスト（未ログイン）の場合" do
        it "共有の定型文は完了画面へ進み、完了画面に表示される" do
          expect {
            post message_logs_path, params: { flow_item_key: shared_item.key }
          }.not_to change(MessageLog, :count)
          expect(response).to redirect_to(message_completion_path)
          expect(session[:last_flow_item_key]).to eq(shared_item.key)

          get message_completion_path
          expect(response.body).to include("共有の定型文")
        end

        it "他人の非公開の定型文は 404 になり、session に入らない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          expect(response).to have_http_status(:not_found)
          expect(session[:last_flow_item_key]).to be_nil
        end

        it "他人の非公開の定型文の中身が、完了画面に出ない" do
          post message_logs_path, params: { flow_item_key: others_private_item.key }

          get message_completion_path
          expect(response.body).not_to include("他人の秘密の定型文")
        end

        it "存在しない key は 404 になる" do
          post message_logs_path, params: { flow_item_key: "no-such-key" }
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
  # まばたき画面は、同じ POST /message_logs に JSON で { flow_item_key, submission_id } を送る。
  # submission_id（送信ID）は画面が「はい」のたびに 1 つ作る UUID で、送り直しでも同じ値を使う。
  # サーバーは「この人がこの ID で前に保存したか」を見て、二重に記録しない。
  describe "POST /message_logs（JSON・送信ID 付き）" do
    def post_json(key, submission_id)
      post message_logs_path,
           params: { flow_item_key: key, submission_id: submission_id }.compact.to_json,
           headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end

    let(:sid) { SecureRandom.uuid }
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:flow_item) { create(:flow_item, user: nil, name: "おちゃ") }
    let(:another_item) { create(:flow_item, user: nil, name: "みず") }

    context "ログイン中のユーザーの場合" do
      before { sign_in user }

      it "201 で名前と「履歴に保存した」を返し、記録が 1 件増える" do
        expect { post_json(flow_item.key, sid) }.to change { user.message_logs.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(response.media_type).to eq("application/json")
        expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => true)
        expect(user.message_logs.last).to have_attributes(flow_item: flow_item, submission_id: sid)
      end

      it "応答をキャッシュさせない（Cache-Control: no-store）" do
        post_json(flow_item.key, sid)
        expect(response.headers["Cache-Control"]).to eq("no-store")
      end

      it "flash を入れない（次に開いた画面に「伝えました」が出ない）" do
        post_json(flow_item.key, sid)
        expect(flash[:notice]).to be_nil

        get message_categories_path
        expect(response.body).not_to include(I18n.t("message_logs.created"))
      end

      it "同じ送信IDを 2 回送っても記録は 1 件。2 回目は 200 で「保存済み」を返す" do
        expect { post_json(flow_item.key, sid) }.to change(MessageLog, :count).by(1)
        expect(response).to have_http_status(:created)

        expect { post_json(flow_item.key, sid) }.not_to change(MessageLog, :count)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => true, "already_saved" => true)
      end

      it "保存済みを返す時の名前は、その記録に保存された名前（あとで定型文の名前が変わっても）" do
        post_json(flow_item.key, sid)
        flow_item.update!(name: "こうちゃ")

        post_json(flow_item.key, sid)
        expect(response.parsed_body["name"]).to eq("おちゃ")
      end

      it "同じ送信IDで別の定型文が来たら 409 で、記録は増えない" do
        post_json(flow_item.key, sid)

        expect { post_json(another_item.key, sid) }.not_to change(MessageLog, :count)
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to eq("error" => "submission_id_conflict")
      end

      it "別の送信IDで同じ定型文を送ると、もう 1 件記録される" do
        post_json(flow_item.key, sid)

        expect { post_json(flow_item.key, SecureRandom.uuid) }.to change(MessageLog, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it "ほかの人が同じ送信IDを使っていても、それぞれ記録される" do
        create(:message_log, user: other_user, submission_id: sid)

        expect { post_json(flow_item.key, sid) }.to change { user.message_logs.count }.by(1)
        expect(response).to have_http_status(:created)
      end

      [
        [ "無い", nil ],
        [ "空文字", "" ],
        [ "UUID の形でない", "not-a-uuid" ],
        [ "桁が足りない", "0f8fad5b-d9cb-469f-a165-70867728950" ]
      ].each do |label, value|
        it "送信IDが#{label}と 422 で、記録は増えない" do
          expect { post_json(flow_item.key, value) }.not_to change(MessageLog, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body).to eq("error" => "invalid_submission_id")
        end
      end

      it "送信IDの前後の空白と大文字は、そろえてから保存する（そろえた後の値で同じ送信とみなす）" do
        post_json(flow_item.key, "  #{sid.upcase}\n")
        expect(response).to have_http_status(:created)
        expect(user.message_logs.last.submission_id).to eq(sid)

        expect { post_json(flow_item.key, sid) }.not_to change(MessageLog, :count)
        expect(response).to have_http_status(:ok)
      end

      it "他人の非公開の定型文は 404 になり、記録は増えない" do
        private_item = create(:flow_item, user: other_user, icon_color: "gray")

        expect { post_json(private_item.key, sid) }.not_to change(MessageLog, :count)
        expect(response).to have_http_status(:not_found)
      end

      # 詳細フロー（量・温度などを順に答える画面）の途中の回答は session[:detail_flow] に入っている。
      # まばたき画面からの記録は、別タブの途中回答を勝手に付けたり消したりしない。
      describe "詳細フローの途中の回答が session にある時" do
        let(:flow_item) { create(:flow_item, user: nil, name: "おちゃ", detail_flow_key: "drink_detail") }

        before do
          get detail_flow_step_path(flow_item.key, 0)
          post detail_flow_step_submit_path(flow_item.key, 0), params: { answer: "small" }
        end

        it "JSON の記録には詳細の回答を付けず、途中の回答も消さない" do
          post_json(flow_item.key, sid)

          expect(user.message_logs.last).to have_attributes(detail_flow_text: nil, detail_flow_data: nil)
          expect(session[:detail_flow]).to include("flow_item_key" => flow_item.key)
          expect(session[:detail_flow]["answers"].keys).to eq([ "amount" ])
        end

        it "そのあと今までの画面（HTML）から送れば、途中の回答が付く（残っていた証拠）" do
          post_json(flow_item.key, sid)
          post message_logs_path, params: { flow_item_key: flow_item.key }

          expect(user.message_logs.order(:id).last.detail_flow_text).to eq("量：少し")
        end
      end

      # 2 つの送信がほぼ同時に届いた時の並びを作る:
      # こちらの送信が「この送信ID の記録はまだ無い」と確かめた直後に、もう一方の送信が先に保存する。
      # （本物の同時実行はテストの中で作れないので、確かめる所 find_by の直後に 1 件はさむ）
      describe "同じ送信が同時に 2 回届いた時" do
        def other_request_saves_first(item)
          raced = false
          allow_any_instance_of(MessageLog.const_get(:ActiveRecord_Associations_CollectionProxy))
            .to receive(:find_by).and_wrap_original do |original, *args|
              found = original.call(*args)
              unless raced
                MessageLog.insert!({ user_id: user.id, flow_item_id: item.id, flow_item_name: item.name, submission_id: sid })
              end
              raced = true
              found
            end
        end

        # モデルの検査（uniqueness）も「まだ無い」と判断した、という並び。最後に止めるのは DB の一意制約だけ
        def model_validation_misses_it
          allow_any_instance_of(MessageLog).to receive(:valid?).and_return(true)
        end

        it "モデルの検査が気づいたら、先の記録を 200 で返し、記録は 1 件だけ" do
          other_request_saves_first(flow_item)

          expect { post_json(flow_item.key, sid) }.to change(MessageLog, :count).by(1)
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => true, "already_saved" => true)
        end

        it "モデルの検査もすり抜けたら DB の一意制約が止め、先の記録を 200 で返し、記録は 1 件だけ" do
          other_request_saves_first(flow_item)
          model_validation_misses_it

          expect { post_json(flow_item.key, sid) }.to change(MessageLog, :count).by(1)
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => true, "already_saved" => true)
        end

        it "先に保存されたのが別の定型文なら 409 で、こちらの記録は作られない" do
          other_request_saves_first(another_item)
          model_validation_misses_it

          expect { post_json(flow_item.key, sid) }.to change(MessageLog, :count).by(1)
          expect(response).to have_http_status(:conflict)
          expect(response.parsed_body).to eq("error" => "submission_id_conflict")
          expect(user.message_logs.pluck(:flow_item_id)).to eq([ another_item.id ])
        end
      end
    end

    context "ゲスト（未ログイン）の場合" do
      it "201 で名前と「履歴には保存しない」を返し、記録は増えず、session に key が入る" do
        expect { post_json(flow_item.key, sid) }.not_to change(MessageLog, :count)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => false)
        expect(session[:last_flow_item_key]).to eq(flow_item.key)
        expect(flash[:notice]).to be_nil
      end

      it "同じ送信IDを 2 回送ると、2 回目は 200 で、session を書き換えない" do
        post_json(flow_item.key, sid)
        # あいだに今までの画面から別の定型文を送った。最後に伝えたのは「みず」
        post message_logs_path, params: { flow_item_key: another_item.key }

        post_json(flow_item.key, sid)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("name" => "おちゃ", "saved_to_history" => false, "already_saved" => true)
        expect(session[:last_flow_item_key]).to eq(another_item.key)
        expect(session[:blink_submission_ids]).to eq([ sid ])
      end

      it "覚えておく送信IDは最新の 10 個だけ（古いものから忘れる）" do
        sids = Array.new(11) { SecureRandom.uuid }
        sids.each { |id| post_json(flow_item.key, id) }

        expect(session[:blink_submission_ids]).to eq(sids.last(10))

        post_json(flow_item.key, sids.last)
        expect(response).to have_http_status(:ok)
        post_json(flow_item.key, sids.first)
        expect(response).to have_http_status(:created)
      end

      it "送信IDの形がおかしければ 422 で、session に何も入らない" do
        post_json(flow_item.key, "not-a-uuid")

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq("error" => "invalid_submission_id")
        expect(session[:last_flow_item_key]).to be_nil
        expect(session[:blink_submission_ids]).to be_nil
      end

      it "ユーザーが作った（共有でない）定型文は 404 になり、session に入らない" do
        private_item = create(:flow_item, user: other_user, icon_color: "gray")
        post_json(private_item.key, sid)

        expect(response).to have_http_status(:not_found)
        expect(session[:last_flow_item_key]).to be_nil
      end
    end

    describe "今までの画面（HTML・送信IDなし）" do
      it "ログイン中は今まで通り。2 回押せば 2 件記録され、完了画面へ進み、flash が入る" do
        sign_in user

        expect {
          2.times { post message_logs_path, params: { flow_item_key: flow_item.key } }
        }.to change(MessageLog, :count).by(2)
        expect(response).to redirect_to(message_completion_path)
        expect(flash[:notice]).to eq(I18n.t("message_logs.created"))
        expect(user.message_logs.pluck(:submission_id)).to eq([ nil, nil ])
      end

      it "ゲストは今まで通り。記録は増えず、session に key が入り、送信IDは覚えない" do
        expect { post message_logs_path, params: { flow_item_key: flow_item.key } }.not_to change(MessageLog, :count)

        expect(response).to redirect_to(message_completion_path)
        expect(session[:last_flow_item_key]).to eq(flow_item.key)
        expect(session[:blink_submission_ids]).to be_nil
      end
    end
  end
end
