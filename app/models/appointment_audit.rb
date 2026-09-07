class AppointmentAudit < ApplicationRecord
  belongs_to :appointment
  belongs_to :actor, class_name: "User", optional: true

  enum :action, { created: 0, rescheduled: 1, cancelled: 2 }
end
