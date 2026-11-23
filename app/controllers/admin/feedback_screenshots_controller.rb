# ご意見箱の添付画像を、管理者にだけ返す。
# Active Storage が用意する URL はログインを確かめないため使わず（config/application.rb で止めている）、
# 画像はこのコントローラーからだけ取れる。
class Admin::FeedbackScreenshotsController < ApplicationController
  include AdminRequired

  # 画像のファイルが保存先に無い場合（保存先が消えた・入れ替わったなど）
  rescue_from(ActiveStorage::FileNotFoundError) { head :not_found }

  def show
    feedback = Feedback.find_by!(key: params[:feedback_key])
    # このご意見に付いている画像の中からだけ探す（他のご意見の画像や、どこにも付いていない画像は 404）
    blob = feedback.screenshots_blobs.find_signed(params[:signed_id], purpose: Feedback::SCREENSHOT_SIGNED_ID_PURPOSE)
    raise ActiveRecord::RecordNotFound if blob.nil?

    no_store
    send_data blob.download,
              filename: blob.filename.sanitized,
              type: blob.content_type_for_serving,
              disposition: blob.forced_disposition_for_serving || :inline
  end
end
