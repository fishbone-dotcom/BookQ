module Staff
  class DoctorsController < BaseController
    def index
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
    end
  end
end
