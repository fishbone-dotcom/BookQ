module Staff
  class PatientsController < BaseController
    TABS = %w[overview appointments records files].freeze

    def index
      @patients = patient_scope.includes(:patient_profile).order(:name, :email)
    end

    def show
      @patient = patient_scope.find(params[:id])
      @profile = @patient.patient_profile
      @tab = TABS.include?(params[:tab]) ? params[:tab] : "overview"
      @appointments = @clinic.appointments.where(patient: @patient).includes(:service, :staff).order(starts_at: :desc) if @tab == "appointments"
    end

    def edit
      @patient = patient_scope.find(params[:id])
      @profile = @patient.patient_profile || @patient.build_patient_profile
    end

    def update
      @patient = patient_scope.find(params[:id])
      @profile = @patient.patient_profile || @patient.build_patient_profile

      if @profile.update(profile_params)
        redirect_to staff_patient_path(@patient), notice: "Patient profile updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def patient_scope
      User.joins(:patient_appointments).where(appointments: { clinic_id: @clinic.id }).distinct
    end

    def profile_params
      params.require(:patient_profile).permit(:birthdate, :sex, :phone, :address, :blood_type, :allergies,
        :emergency_contact_name, :emergency_contact_relationship, :emergency_contact_phone)
    end
  end
end
