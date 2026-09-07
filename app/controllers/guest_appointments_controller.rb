class GuestAppointmentsController < ApplicationController
  before_action :set_appointment

  def show
  end

  def cancel
    @appointment.cancel!(by: nil, reason: "Cancelled by guest")
    redirect_to guest_appointment_path(params[:token]), notice: "Your booking has been cancelled."
  end

  private

  def set_appointment
    @appointment = Appointment.find_signed(params[:token], purpose: :guest_management)
    head :not_found if @appointment.nil? || !@appointment.guest?
  end
end
