class MessageCompletionsController < ApplicationController
  def show
    @message_log = current_user.message_logs.order(created_at: :desc).first
  end
end
