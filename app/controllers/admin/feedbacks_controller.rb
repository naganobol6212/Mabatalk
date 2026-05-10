class Admin::FeedbacksController < ApplicationController
  include AdminRequired

  def index
    @feedbacks = Feedback.includes(:screenshots_attachments, :user)
                          .order(created_at: :desc)
  end

  def show
    @feedback = Feedback.includes(:screenshots_attachments, :user)
                        .find_by!(key: params[:key])
  end
end
