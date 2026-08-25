module Staff
  class ClinicStaffsController < BaseController
    before_action :require_owner!

    def index
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
    end

    def update
      clinic_staff = @clinic.clinic_staffs.find(params[:id])

      if clinic_staff.user_id == current_user.id
        return redirect_to staff_clinic_staffs_path, alert: "You can't change your own role."
      end

      if clinic_staff.update(role: params[:role])
        redirect_to staff_clinic_staffs_path, notice: "#{clinic_staff.user.display_name}'s role updated."
      else
        redirect_to staff_clinic_staffs_path, alert: clinic_staff.errors.full_messages.to_sentence
      end
    end

    def destroy
      clinic_staff = @clinic.clinic_staffs.find(params[:id])

      if clinic_staff.user_id == current_user.id
        return redirect_to staff_clinic_staffs_path, alert: "You can't remove yourself from the clinic."
      end

      name = clinic_staff.user.display_name
      clinic_staff.destroy
      redirect_to staff_clinic_staffs_path, notice: "#{name} removed from the clinic."
    end

    private

    def require_owner!
      redirect_to staff_settings_path, alert: "Only clinic owners can manage staff." unless @clinic_staff&.owner?
    end
  end
end
