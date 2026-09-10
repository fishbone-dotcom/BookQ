class Appointment < ApplicationRecord
  belongs_to :patient, class_name: "User", optional: true, inverse_of: :patient_appointments
  belongs_to :clinic
  belongs_to :service
  belongs_to :staff, class_name: "User", optional: true, inverse_of: :staff_appointments

  has_many :audits, class_name: "AppointmentAudit", dependent: :destroy
  has_one :payment, dependent: :destroy

  # Transient — set by a caller right before save/update! so the audit
  # callbacks below know who's acting and (optionally) why. Not persisted.
  attr_accessor :audit_actor, :audit_reason

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3 }

  scope :active, -> { where(status: [ :pending, :confirmed ]) }

  before_validation :normalize_guest_contact_info

  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :no_overlapping_appointments
  validate :patient_has_no_other_active_appointment
  validate :patient_or_guest_contact_present
  validate :guest_email_not_registered
  validate :guest_has_no_other_active_appointment_at_clinic

  after_create :record_creation_audit
  after_update :record_change_audit, if: :saved_change_to_status_or_schedule?

  def active?
    pending? || confirmed?
  end

  def guest?
    patient_id.nil?
  end

  def payment_required?
    service.price.present? && service.price.positive?
  end

  # A guest appointment already claimed by a real account still keeps its
  # original guest_* fields as a historical record — patient presence is
  # what actually determines identity everywhere else, so this only matters
  # for genuinely-unclaimed guest bookings.
  def contact_name
    patient&.display_name || guest_name
  end

  def contact_email
    patient&.email || guest_email
  end

  def contact_phone
    patient&.patient_profile&.phone || guest_phone
  end

  def cancel!(by:, reason: nil)
    return unless active?

    self.audit_actor = by
    self.audit_reason = reason
    update!(status: :cancelled)
  end

  private

  def normalize_guest_contact_info
    self.guest_name = guest_name.strip.presence if guest_name.present?
    self.guest_email = guest_email.strip.downcase.presence if guest_email.present?
    self.guest_phone = guest_phone.strip.presence if guest_phone.present?
  end

  def record_creation_audit
    audits.create!(action: :created, actor: audit_actor, reason: audit_reason)
  end

  def record_change_audit
    action = saved_change_to_status? && cancelled? ? :cancelled : :rescheduled
    audits.create!(action: action, actor: audit_actor, reason: audit_reason,
      previous_starts_at: saved_change_to_starts_at? ? starts_at_before_last_save : nil)
  end

  def saved_change_to_status_or_schedule?
    saved_change_to_status? || saved_change_to_starts_at? || saved_change_to_staff_id?
  end

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

    errors.add(:base, "Someone else just booked that time — please pick a different one.") if overlapping.exists?
  end

  def patient_has_no_other_active_appointment
    return if patient_id.blank? || !active?

    has_active = Appointment.active.where(patient_id: patient_id).where.not(id: id).exists?
    errors.add(:base, "You already have an active booking. Only one active booking is allowed per patient.") if has_active
  end

  def patient_or_guest_contact_present
    return if patient.present? || (guest_name.present? && guest_email.present?)

    errors.add(:base, "Please provide your name and email, or sign in.")
  end

  # A guest booking under an email that already has a real account would let
  # a stranger create (and, via the tokenized management link, cancel)
  # appointments that show up on someone else's account without ever
  # authenticating as them — block it outright and point them at login.
  def guest_email_not_registered
    return if patient.present? || guest_email.blank?

    errors.add(:guest_email, "is already registered — please log in to book.") if User.exists?(email: guest_email)
  end

  # Deliberately per-clinic, not global like the authenticated-patient rule
  # above — a guest legitimately booking at several different clinics is
  # normal, but repeatedly holding slots at the same clinic under one email
  # is the abuse case worth blocking.
  def guest_has_no_other_active_appointment_at_clinic
    return if patient.present? || guest_email.blank? || !active?

    has_active = Appointment.active.where(clinic_id: clinic_id, guest_email: guest_email).where.not(id: id).exists?
    errors.add(:base, "You already have an active booking at this clinic with this email.") if has_active
  end
end
