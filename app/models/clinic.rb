class Clinic < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_clinics

  has_many :clinic_staffs, dependent: :destroy
  has_many :staff_members, through: :clinic_staffs, source: :user
  has_many :services, dependent: :destroy
  has_many :availabilities, dependent: :destroy
  has_many :appointments, dependent: :destroy

  validates :name, presence: true
end
