class Service < ApplicationRecord
  belongs_to :clinic

  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
