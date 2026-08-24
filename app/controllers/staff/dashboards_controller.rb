module Staff
  class DashboardsController < BaseController
    def show
      @today_appointments_count = @clinic.appointments.where(starts_at: Date.current.all_day).count
      @doctors_count = @clinic.clinic_staffs.count
      @total_patients_count = @clinic.appointments.distinct.count(:patient_id)
      @new_patients_this_month_count = new_patients_this_month_count
      @recent_appointments = @clinic.appointments.includes(:patient, :service, :staff)
        .where(starts_at: Time.current..)
        .where.not(status: :cancelled)
        .order(starts_at: :asc)
        .limit(5)
    end

    private

    def new_patients_this_month_count
      first_appointment_dates = @clinic.appointments.group(:patient_id).minimum(:created_at)
      first_appointment_dates.count { |_, created_at| created_at.to_date.between?(Date.current.beginning_of_month, Date.current.end_of_month) }
    end
  end
end
