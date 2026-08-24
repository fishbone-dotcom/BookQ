module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    private

    def require_admin!
      redirect_to root_path, alert: "Hindi ka pinapayagang pumunta dito." unless current_user.admin?
    end
  end
end
