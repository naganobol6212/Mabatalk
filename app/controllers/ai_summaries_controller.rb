class AiSummariesController < ApplicationController
  before_action :authenticate_user!

  def create
    current_user.with_lock do
      summary = current_user.ai_summary

      if summary&.persisted? && !summary.regeneratable?
        return redirect_to analytics_path,
                            alert: t("ai_summary.create.too_soon",
                                    date: l(summary.next_regeneratable_at.to_date))
      end

      unless current_user.message_logs.where(created_at: 30.days.ago..).exists?
        return redirect_to analytics_path, alert: t("ai_summary.create.no_logs")
      end
    end

    content = AiSummaryService.call(user: current_user)

    current_user.with_lock do
      summary = current_user.ai_summary || current_user.build_ai_summary
      summary.update!(content: content, generated_at: Time.current)
    end

    redirect_to analytics_path, notice: t("ai_summary.create.success")

  rescue Timeout::Error
    Rails.logger.warn("AiSummary timeout for user_id=#{current_user.id}")
    redirect_to analytics_path, alert: t("ai_summary.create.timeout")
  rescue Anthropic::Errors::APITimeoutError => e
    Rails.logger.warn("AiSummary API timeout for user_id=#{current_user.id}: #{e.message}")
    redirect_to analytics_path, alert: t("ai_summary.create.timeout")
  rescue Anthropic::Errors::APIError => e
    Rails.logger.error("Anthropic API error for user_id=#{current_user.id}: #{e.message}")
    redirect_to analytics_path, alert: t("ai_summary.create.error")
  rescue StandardError => e
    Rails.logger.error("AiSummary unexpected error for user_id=#{current_user.id}: #{e.class}: #{e.message}")
    redirect_to analytics_path, alert: t("ai_summary.create.error")
  end
end
