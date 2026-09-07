class HomeController < ApplicationController
  def index
    @clinics = Clinic.order(:name)
    return unless user_signed_in?

    @active_appointment = current_user.patient_appointments.active.includes(:clinic, :service, :staff).order(:starts_at).first
  end
end
