module Staff
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :set_clinic

    private

    def set_clinic
      @clinic = current_user.clinics.first
      redirect_to root_path, alert: "You are not staff at any clinic." if @clinic.nil?
    end
  end
end
