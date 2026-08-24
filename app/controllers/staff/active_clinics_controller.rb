module Staff
  class ActiveClinicsController < ApplicationController
    before_action :authenticate_user!

    def update
      clinic = current_user.clinics.find_by(id: params[:clinic_id])
      session[:staff_clinic_id] = clinic.id if clinic
      redirect_to staff_dashboard_path
    end
  end
end
