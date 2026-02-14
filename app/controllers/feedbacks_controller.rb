class FeedbacksController < ApplicationController
  def new
  end

  def create
    redirect_to settings_path, notice: "送信ありがとうございました！"
  end
end
