class AppointmentMailer < ApplicationMailer
  def reminder(appointment)
    @appointment = appointment
    @clinic = appointment.clinic
    @service = appointment.service

    mail(
      to: appointment.patient.email,
      subject: "Reminder: your #{@service.name} appointment at #{@clinic.name} is tomorrow"
    )
  end
end
