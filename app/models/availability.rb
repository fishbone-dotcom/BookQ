class Availability < ApplicationRecord
  belongs_to :clinic

  enum :day_of_week, { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
