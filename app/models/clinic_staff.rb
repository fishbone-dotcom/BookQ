class ClinicStaff < ApplicationRecord
  belongs_to :clinic
  belongs_to :user

  enum :role, { staff: 0, owner: 1 }

  validates :user_id, uniqueness: { scope: :clinic_id }
end
