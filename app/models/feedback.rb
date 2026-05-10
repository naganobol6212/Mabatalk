class Feedback < ApplicationRecord
  MAX_SCREENSHOTS = 3
  MAX_SCREENSHOT_SIZE = 5.megabytes
  ALLOWED_TYPES_AND_EXTENSIONS = {
    "image/png" => [".png"],
    "image/jpeg" => [".jpg", ".jpeg"],
    "image/gif" => [".gif"]
  }.freeze
  BODY_MAX_LENGTH = 1000

  belongs_to :user, optional: true
  has_many_attached :screenshots

  enum :category, { bug: 0, request: 1, other: 2 }

  before_validation :set_key, on: :create

  validates :key, presence: true, uniqueness: true
  validates :body, presence: true, length: { maximum: BODY_MAX_LENGTH }
  validates :category, presence: true
  validate :validate_screenshots_count
  validate :validate_screenshots_content_type
  validate :validate_screenshots_size

  def category_label
    I18n.t("feedbacks.categories.#{category}")
  end

  def to_param
    key
  end

  private

  def set_key
    self.key ||= SecureRandom.uuid
  end

  def validate_screenshots_count
    return if screenshots.size <= MAX_SCREENSHOTS

    errors.add(:screenshots, :too_many, count: MAX_SCREENSHOTS)
  end

  def validate_screenshots_content_type
    screenshots.each do |screenshot|
      extension = File.extname(screenshot.filename.to_s).downcase
      allowed_extensions = ALLOWED_TYPES_AND_EXTENSIONS[screenshot.content_type]
      next if allowed_extensions&.include?(extension)

      errors.add(:screenshots, :invalid_content_type)
      break
    end
  end

  def validate_screenshots_size
    screenshots.each do |screenshot|
      next if screenshot.byte_size <= MAX_SCREENSHOT_SIZE

      errors.add(:screenshots, :too_large, size: MAX_SCREENSHOT_SIZE / 1.megabyte)
      break
    end
  end
end
