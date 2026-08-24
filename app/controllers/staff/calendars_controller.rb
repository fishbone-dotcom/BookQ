module Staff
  class CalendarsController < BaseController
    def show
      @date = parse_date(params[:date]) || Date.current
      @week_start = @date.beginning_of_week(:sunday)
      @week_days = (@week_start..@week_start + 6.days).to_a

      @availability = @clinic.availabilities.find_by(day_of_week: @date.wday)
      return unless @availability

      appointments = @clinic.appointments.includes(:patient, :service)
        .where(starts_at: @date.all_day)
        .where.not(status: :cancelled)
        .order(:starts_at)
      @placements = CalendarLayout.new(appointments).placements
    end

    private

    def parse_date(value)
      Date.iso8601(value) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
