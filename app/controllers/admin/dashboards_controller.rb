module Admin
  class DashboardsController < BaseController
    RECENT_LIMIT = 8

    def show
      @clinic_count = Clinic.count
      @user_count = User.count
      @appointment_counts = Appointment.group(:status).count
      @total_appointments = Appointment.count

      @recent_appointments = Appointment.includes(:patient, :clinic, :service, :staff)
        .where(starts_at: Time.current..)
        .where.not(status: :cancelled)
        .order(starts_at: :asc)
        .limit(RECENT_LIMIT)
    end
  end
end
