module Staff
  class PatientsController < BaseController
    def index
      @patients = User.joins(:patient_appointments)
        .where(appointments: { clinic_id: @clinic.id })
        .includes(:patient_profile)
        .distinct
        .order(:name, :email)
    end
  end
end
