class MessageLogsController < ApplicationController
  before_action :authenticate_user!, only: [ :index ]

  def index
    @message_logs = MessageLog.for_viewer(current_user).includes(:user)
  end

  # ゲストの session に覚えておく送信ID の数（session は cookie に入るので、大きくしすぎない）
  GUEST_SUBMISSION_LIMIT = 10

  def create
    flow_item = FlowItem.for_user(current_user).find_by!(key: params[:flow_item_key])

    respond_to do |format|
      format.html { create_html(flow_item) }
      format.json { create_json(flow_item) }
    end
  end

  private

  # 今までの画面（確認画面のフォーム）からの送信
  def create_html(flow_item)
    if user_signed_in?
      detail_text, detail_data = build_detail_flow(flow_item)
      MessageLog.create!(
        user: current_user,
        flow_item: flow_item,
        detail_flow_text: detail_text,
        detail_flow_data: detail_data
      )
      session.delete(:detail_flow)
      flash[:notice] = t("message_logs.created")
    else
      session[:last_flow_item_key] = flow_item.key
    end

    redirect_to message_completion_path
  end

  # まばたき画面からの送信。送り直しでも同じ送信ID が来るので、二重に記録しない。
  # flash・詳細の回答・session[:detail_flow] には触らない。
  def create_json(flow_item)
    # 付くのは、ここから返す JSON（201・200・409・送信ID の 422）だけ。
    # ここに来る前に起きる例外の応答（定型文が見つからない 404・CSRF の 422 など）には付かない
    response.headers["Cache-Control"] = "no-store"

    submission_id = params[:submission_id].to_s.strip.downcase
    unless submission_id.match?(MessageLog::SUBMISSION_ID_FORMAT)
      return render json: { error: "invalid_submission_id" }, status: :unprocessable_entity
    end

    if user_signed_in?
      create_json_for_user(flow_item, submission_id)
    else
      create_json_for_guest(flow_item, submission_id)
    end
  end

  def create_json_for_user(flow_item, submission_id)
    existing = current_user.message_logs.find_by(submission_id: submission_id)
    return render_existing(existing, flow_item) if existing

    log = current_user.message_logs.create!(flow_item: flow_item, submission_id: submission_id)
    render json: { name: log.flow_item_name, saved_to_history: true }, status: :created
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # 同じ送信がほぼ同時に 2 つ届き、もう一方が先に保存した時だけここで受ける。ほかの検査エラーは隠さない
    raise if e.is_a?(ActiveRecord::RecordInvalid) && !e.record.errors.of_kind?(:submission_id, :taken)

    render_existing(current_user.message_logs.find_by!(submission_id: submission_id), flow_item)
  end

  def render_existing(log, flow_item)
    if log.flow_item_id == flow_item.id
      render json: { name: log.flow_item_name, saved_to_history: true, already_saved: true }, status: :ok
    else
      render json: { error: "submission_id_conflict" }, status: :conflict
    end
  end

  # ゲストは記録（MessageLog）を作らないので、送信ID は session に最近の分だけ覚える
  def create_json_for_guest(flow_item, submission_id)
    recent = Array(session[:blink_submission_ids])
    if recent.include?(submission_id)
      return render json: { name: flow_item.name, saved_to_history: false, already_saved: true }, status: :ok
    end

    session[:last_flow_item_key] = flow_item.key
    session[:blink_submission_ids] = (recent + [ submission_id ]).last(GUEST_SUBMISSION_LIMIT)
    render json: { name: flow_item.name, saved_to_history: false }, status: :created
  end

  def build_detail_flow(flow_item)
    df = session[:detail_flow]
    return [ nil, nil ] unless df&.dig("flow_item_key") == flow_item.key

    answers    = df["answers"] || {}
    definition = DetailFlowDefinitions.find(flow_item.detail_flow_key)
    return [ nil, nil ] unless definition

    parts = definition[:steps].filter_map do |step|
      ans = answers[step[:key]]
      next unless ans
      "#{step[:label]}：#{ans['label']}"
    end

    [ parts.join("、").presence, answers.presence ]
  end
end
