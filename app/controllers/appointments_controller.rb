class AppointmentsController < ApplicationController
  before_action :authenticate_user!

  def update
    appointment = current_user.patient_appointments.find(params[:id])
    result = AppointmentBooking.new(clinic: appointment.clinic, params: params).reschedule(appointment)

    if result.success?
      redirect_to root_path, notice: "Your appointment has been updated."
    else
      redirect_to clinic_booking_path(appointment.clinic, service_id: params[:service_id], month: params[:month],
        date: params[:date], staff_id: params[:staff_id]), alert: result.error
    end
  end

  def cancel
    appointment = current_user.patient_appointments.find(params[:id])

    if appointment.active?
      appointment.cancel!
      redirect_to root_path, notice: "Your booking has been cancelled."
    else
      redirect_to clinic_booking_path(appointment.clinic, service_id: appointment.service_id), alert: "This booking can no longer be cancelled."
    end
  end
end
