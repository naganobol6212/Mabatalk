class AnalyticsController < ApplicationController
  before_action :authenticate_user!

  def show
    @month       = parse_month(params[:month])
    @stats       = LogStatsService.call(user: current_user, month: @month)
    @prev_month  = @month.prev_month
    @next_month  = @month.next_month
    @future_month = @next_month > Date.current.beginning_of_month
    @ai_summary = current_user.ai_summary
    @recent_log_count = current_user.message_logs
                                    .where(created_at: 30.days.ago..)
                                    .count
  end

  private

  def parse_month(param)
    return Date.current.beginning_of_month if param.blank?

    Date.parse("#{param}-01").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end
end
