class Appointment < ApplicationRecord
  belongs_to :patient, class_name: "User", inverse_of: :patient_appointments
  belongs_to :clinic
  belongs_to :service
  belongs_to :staff, class_name: "User", optional: true, inverse_of: :staff_appointments

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3 }

  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :no_overlapping_appointments

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
  end

  def no_overlapping_appointments
    return if clinic_id.blank? || starts_at.blank? || ends_at.blank?

    overlapping = Appointment
      .where(clinic_id: clinic_id)
      .where.not(status: :cancelled)
      .where.not(id: id)
      .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)

    overlapping = overlapping.where(staff_id: staff_id) if staff_id.present?

    errors.add(:base, "Naunahan ka na — nabook na ng iba ang oras na ito.") if overlapping.exists?
  end
end
