class Admin::FeedbacksController < ApplicationController
  include AdminRequired

  def index
    @feedbacks = Feedback.includes(:screenshots_attachments, :user)
                          .order(created_at: :desc)
  end

  def show
    @feedback = Feedback.with_attached_screenshots
                        .includes(:user)
                        .find(params[:id])
  end
end
