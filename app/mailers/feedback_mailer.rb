class FeedbackMailer < ApplicationMailer
  def notify_admin(feedback)
    @feedback = feedback
    admin_email = Rails.application.credentials.dig(:admin, :email)
    raise "Admin emails not configured (credentials.admin.email)" if admin_email.blank?

    mail(
      to: admin_email,
      subject: t("feedback_mailer.notify_admin.subject", category: feedback.category_label)
    )
  end
end
