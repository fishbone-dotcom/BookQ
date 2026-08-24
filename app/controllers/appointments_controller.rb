class AppointmentsController < ApplicationController
  before_action :authenticate_user!

  def cancel
    appointment = current_user.patient_appointments.find(params[:id])

    if appointment.active?
      appointment.cancel!
      redirect_to clinic_booking_path(appointment.clinic, service_id: appointment.service_id), notice: "Nakansela ang booking mo."
    else
      redirect_to clinic_booking_path(appointment.clinic, service_id: appointment.service_id), alert: "Hindi na makansela ang booking na ito."
    end
  end
end
