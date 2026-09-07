class Availability < ApplicationRecord
  self.skip_time_zone_conversion_for_attributes = [ :start_time, :end_time ]

  belongs_to :clinic
  belongs_to :clinic_staff, optional: true

  enum :day_of_week, { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }

  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :clinic_staff_id, uniqueness: { scope: [ :clinic_id, :day_of_week ] }
  validate :end_time_after_start_time
  validate :clinic_staff_belongs_to_clinic

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  # nil clinic_staff_id means "clinic-wide default hours"; a real one must
  # actually staff this same clinic, not one filed under the wrong tenant.
  def clinic_staff_belongs_to_clinic
    return if clinic_staff.blank? || clinic_id.blank?

    errors.add(:clinic_staff, "must belong to the same clinic") if clinic_staff.clinic_id != clinic_id
  end
end
