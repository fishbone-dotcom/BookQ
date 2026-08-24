module Staff
  class AppointmentsController < BaseController
    STATUSES = %w[all confirmed pending cancelled].freeze

    def index
      @date = parse_date(params[:date]) || Date.current
      @status = STATUSES.include?(params[:status]) ? params[:status] : "all"
      @week_start = @date.beginning_of_week(:sunday)
      @week_days = (@week_start..@week_start + 6.days).to_a

      scope = @clinic.appointments.includes(:patient, :service, :staff).where(starts_at: @date.all_day)
      @appointments = filter_by_status(scope).order(:starts_at)
    end

    private

    def filter_by_status(scope)
      case @status
      when "all"
        scope.where.not(status: :cancelled)
      when "cancelled"
        scope.where(status: :cancelled)
      else
        scope.where(status: @status)
      end
    end

    def parse_date(value)
      Date.iso8601(value) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
