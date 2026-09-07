module Staff
  class AvailabilitiesController < BaseController
    before_action :require_owner!

    def index
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
      @selected_clinic_staff = @clinic_staffs.find_by(id: params[:clinic_staff_id])
      @availabilities = Availability.day_of_weeks.keys.index_with do |day|
        @clinic.availabilities.find_by(clinic_staff_id: @selected_clinic_staff&.id, day_of_week: day)
      end
    end

    def update
      clinic_staff_id = params[:clinic_staff_id].presence
      errors = []

      Availability.day_of_weeks.keys.each do |day|
        day_params = params.dig(:availabilities, day)
        next if day_params.nil?

        if day_params[:open] == "1"
          availability = @clinic.availabilities.find_or_initialize_by(clinic_staff_id: clinic_staff_id, day_of_week: day)
          availability.start_time = day_params[:start_time]
          availability.end_time = day_params[:end_time]
          errors << "#{day.capitalize}: #{availability.errors.full_messages.to_sentence}" unless availability.save
        else
          @clinic.availabilities.find_by(clinic_staff_id: clinic_staff_id, day_of_week: day)&.destroy
        end
      end

      if errors.any?
        redirect_to staff_availabilities_path(clinic_staff_id: clinic_staff_id), alert: errors.join(" ")
      else
        redirect_to staff_availabilities_path(clinic_staff_id: clinic_staff_id), notice: "Working hours updated."
      end
    end

    private

    def require_owner!
      redirect_to staff_settings_path, alert: "Only clinic owners can edit working hours." unless @clinic_staff&.owner?
    end
  end
end
