class PatientProfile < ApplicationRecord
  belongs_to :user

  def age
    return nil if birthdate.blank?

    today = Date.current
    years = today.year - birthdate.year
    years -= 1 if today < birthdate + years.years
    years
  end
end
