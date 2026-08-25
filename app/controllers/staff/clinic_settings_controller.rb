module Staff
  class ClinicSettingsController < BaseController
    before_action :require_owner!

    def edit
    end

    def update
      if @clinic.update(clinic_params)
        redirect_to staff_settings_path, notice: "Clinic information updated."
      else
        flash.now[:alert] = @clinic.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def require_owner!
      redirect_to staff_settings_path, alert: "Only clinic owners can edit clinic information." unless @clinic_staff&.owner?
    end

    def clinic_params
      params.require(:clinic).permit(:name, :address, :phone)
    end
  end
end
