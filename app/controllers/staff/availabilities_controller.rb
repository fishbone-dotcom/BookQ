module Staff
  class AvailabilitiesController < BaseController
    before_action :require_owner!

    def index
      @availabilities = Availability.day_of_weeks.keys.index_with { |day| @clinic.availabilities.find_by(day_of_week: day) }
    end

    def update
      errors = []

      Availability.day_of_weeks.keys.each do |day|
        day_params = params.dig(:availabilities, day)
        next if day_params.nil?

        if day_params[:open] == "1"
          availability = @clinic.availabilities.find_or_initialize_by(day_of_week: day)
          availability.start_time = day_params[:start_time]
          availability.end_time = day_params[:end_time]
          errors << "#{day.capitalize}: #{availability.errors.full_messages.to_sentence}" unless availability.save
        else
          @clinic.availabilities.find_by(day_of_week: day)&.destroy
        end
      end

      if errors.any?
        redirect_to staff_availabilities_path, alert: errors.join(" ")
      else
        redirect_to staff_availabilities_path, notice: "Working hours updated."
      end
    end

    private

    def require_owner!
      redirect_to staff_settings_path, alert: "Only clinic owners can edit working hours." unless @clinic_staff&.owner?
    end
  end
end
