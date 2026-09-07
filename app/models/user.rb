class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  enum :role, { patient: 0, staff: 1, admin: 2 }

  has_many :clinic_staffs, dependent: :destroy
  has_many :clinics, through: :clinic_staffs
  has_many :owned_clinics, class_name: "Clinic", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :patient_appointments, class_name: "Appointment", foreign_key: :patient_id, dependent: :destroy, inverse_of: :patient
  has_many :staff_appointments, class_name: "Appointment", foreign_key: :staff_id, dependent: :nullify, inverse_of: :staff
  has_one :patient_profile, dependent: :destroy

  def display_name
    name.presence || email
  end

  def self.from_google(auth)
    find_by(provider: auth.provider, uid: auth.uid) ||
      find_by(email: auth.info.email)&.tap { |u| u.update!(provider: auth.provider, uid: auth.uid) } ||
      create!(provider: auth.provider, uid: auth.uid, email: auth.info.email, name: auth.info.name,
        password: Devise.friendly_token[0, 20], role: :patient)
  end

  # Attaches this user's still-unclaimed guest appointments (matched by
  # email) now that they've proven control of that email via signup —
  # one-way, and only rows with no patient yet, so an appointment already
  # claimed by someone else is never reassigned. Guests may have several
  # active bookings across different clinics (allowed — see
  # Appointment#guest_has_no_other_active_appointment_at_clinic), but a real
  # account is still limited to one active booking overall, so a claim that
  # would violate that is skipped rather than raising — it just stays a
  # guest booking, still manageable via its own tokenized link.
  def claim_guest_appointments!
    Appointment.where(patient_id: nil, guest_email: email).find_each do |appointment|
      appointment.audit_actor = self
      appointment.update(patient_id: id)
    end
  end
end
