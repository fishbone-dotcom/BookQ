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
end
