module Staff
  class ReportsController < BaseController
    PERIODS = %w[this_week this_month last_month all_time].freeze
    PERIOD_LABELS = { "this_week" => "This Week", "this_month" => "This Month",
      "last_month" => "Last Month", "all_time" => "All Time" }.freeze

    def index
    end

    def appointments
      @period = parse_period
      scope = @clinic.appointments.where(starts_at: period_range)

      @total = scope.count
      @by_status = %w[pending confirmed completed cancelled].index_with { |status| scope.where(status: status).count }
    end

    def patients
      @period = parse_period
      range = period_range

      patient_ids = @clinic.appointments.where(starts_at: range).distinct.pluck(:patient_id)
      first_appointment_at = @clinic.appointments.where(patient_id: patient_ids).group(:patient_id).minimum(:starts_at)

      @total_patients = patient_ids.size
      @new_count = patient_ids.count { |id| range.cover?(first_appointment_at[id]) }
      @returning_count = @total_patients - @new_count
    end

    def services
      @period = parse_period
      @service_counts = @clinic.appointments.joins(:service)
        .where(starts_at: period_range)
        .group("services.name")
        .order(Arel.sql("COUNT(*) DESC"))
        .count
      @total = @service_counts.values.sum
    end

    private

    def parse_period
      PERIODS.include?(params[:period]) ? params[:period] : "this_month"
    end

    def period_range
      now = Time.zone.now
      case @period
      when "this_week" then now.beginning_of_week..now.end_of_week
      when "last_month" then 1.month.ago(now).beginning_of_month..1.month.ago(now).end_of_month
      when "all_time" then Time.zone.at(0)..now.end_of_day
      else now.beginning_of_month..now.end_of_month
      end
    end
  end
end
