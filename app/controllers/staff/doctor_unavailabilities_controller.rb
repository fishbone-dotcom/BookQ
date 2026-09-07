module Staff
  class DoctorUnavailabilitiesController < BaseController
    before_action :set_doctor

    def new
    end

    def create
      from_date = parse_date(params[:from_date]) || Date.current
      to_date = parse_date(params[:to_date]) || from_date

      result = DoctorUnavailability.new(
        clinic: @clinic, clinic_staff: @doctor, from_date: from_date, to_date: to_date, triggered_by: current_user
      ).apply!

      redirect_to staff_doctors_path, notice: notice_for(result)
    end

    private

    def set_doctor
      @doctor = @clinic.clinic_staffs.find(params[:doctor_id])
    end

    def notice_for(result)
      if result.cancelled_count.zero?
        "No active appointments were affected."
      else
        "Cancelled #{result.cancelled_count} appointment(s) and notified #{result.cancelled_count} patient(s)."
      end
    end

    def parse_date(value)
      Date.iso8601(value) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
