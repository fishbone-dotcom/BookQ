class SendAppointmentRemindersJob < ApplicationJob
  queue_as :default

  def perform
    due_appointments.find_each do |appointment|
      AppointmentMailer.reminder(appointment).deliver_later
      appointment.update!(reminder_sent_at: Time.current)
    end
  end

  private

  def due_appointments
    Appointment.active
      .where(reminder_sent_at: nil)
      .where(starts_at: Time.current..24.hours.from_now)
  end
end
