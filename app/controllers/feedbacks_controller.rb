class FeedbacksController < ApplicationController
  RATE_LIMIT_PER_DAY = 5

  def new
    @feedback = Feedback.new
  end

  def create
    if rate_limit_exceeded?
      redirect_to new_feedback_path, alert: t("feedbacks.create.rate_limit_exceeded")
      return
    end

    @feedback = Feedback.new(feedback_params)
    @feedback.user = current_user if user_signed_in?

    if @feedback.save
      FeedbackMailer.notify_admin(@feedback).deliver_later
      redirect_to settings_path, notice: t("feedbacks.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:category, :body, screenshots: [])
  end

  def rate_limit_exceeded?
    return false unless user_signed_in?

    Feedback
      .where(user: current_user, created_at: 1.day.ago..)
      .count >= RATE_LIMIT_PER_DAY
  end
end
