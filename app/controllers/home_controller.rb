class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    @clinics = Clinic.order(:name)
    @active_appointment = current_user.patient_appointments.active.includes(:clinic, :service, :staff).order(:starts_at).first
  end
end
