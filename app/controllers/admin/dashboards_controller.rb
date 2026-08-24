module Admin
  class DashboardsController < BaseController
    PER_PAGE = 25

    def show
      @clinic_count = Clinic.count
      @user_count = User.count
      @appointment_counts = Appointment.group(:status).count

      @page = [ params[:page].to_i, 1 ].max
      @total_appointments = Appointment.count
      @total_pages = (@total_appointments.to_f / PER_PAGE).ceil

      @appointments = Appointment.includes(:patient, :clinic, :service, :staff)
        .order(starts_at: :desc)
        .offset((@page - 1) * PER_PAGE)
        .limit(PER_PAGE)
    end
  end
end
