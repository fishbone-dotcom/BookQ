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

      if @tab == "appointments"
        scope = @clinic.appointments.where(patient: @patient)
        scope = scope.where(staff: current_user) unless @clinic_staff&.owner?
        @appointments = scope.includes(:service, :staff).order(starts_at: :desc)
      end
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

    # Owners see every patient who's booked at the clinic; plain staff (doctors)
    # only see patients who have an appointment with them specifically —
    # a doctor has no business seeing another doctor's patients' records.
    def patient_scope
      scope = User.joins(:patient_appointments).where(appointments: { clinic_id: @clinic.id })
      scope = scope.where(appointments: { staff_id: current_user.id }) unless @clinic_staff&.owner?
      scope.distinct
    end

    def profile_params
      params.require(:patient_profile).permit(:birthdate, :sex, :phone, :address, :blood_type, :allergies,
        :emergency_contact_name, :emergency_contact_relationship, :emergency_contact_phone)
    end
  end
end
