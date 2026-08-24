module Staff
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :set_clinic

    layout "staff"

    private

    def set_clinic
      @clinic = current_user.clinics.find_by(id: session[:staff_clinic_id]) || current_user.clinics.first

      if @clinic.nil?
        redirect_to root_path
        return
      end

      session[:staff_clinic_id] = @clinic.id
      @clinic_staff = current_user.clinic_staffs.find_by(clinic: @clinic)
    end
  end
end
