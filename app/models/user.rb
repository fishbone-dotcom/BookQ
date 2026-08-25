class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

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
end
