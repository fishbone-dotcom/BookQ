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

    def new
      load_new_appointment_context
    end

    def create
      patient = patient_scope.find_by(id: params[:patient_id])
      return redirect_to_new(alert: "Please select a patient.") if patient.nil?

      result = AppointmentBooking.new(clinic: @clinic, params: params).create_for(patient)

      if result.success?
        redirect_to staff_appointments_path(date: result.appointment.starts_at.to_date.iso8601),
          notice: "Appointment booked for #{patient.display_name}."
      else
        redirect_to_new(alert: result.error)
      end
    end

    def edit
      @appointment = @clinic.appointments.find(params[:id])
      load_edit_context(@appointment)
    end

    def update
      @appointment = @clinic.appointments.find(params[:id])
      result = AppointmentBooking.new(clinic: @clinic, params: params).reschedule(@appointment)

      if result.success?
        redirect_to staff_appointments_path(date: result.appointment.starts_at.to_date.iso8601),
          notice: "Appointment updated."
      else
        redirect_to_edit(alert: result.error)
      end
    end

    def cancel
      appointment = @clinic.appointments.find(params[:id])

      if appointment.active?
        appointment.cancel!
        redirect_to staff_appointments_path(date: appointment.starts_at.to_date.iso8601), notice: "Appointment cancelled."
      else
        redirect_to staff_appointments_path(date: appointment.starts_at.to_date.iso8601), alert: "This appointment can no longer be cancelled."
      end
    end

    private

    def patient_scope
      User.where(role: :patient)
    end

    def redirect_to_new(**flash)
      redirect_to new_staff_appointment_path(patient_id: params[:patient_id], service_id: params[:service_id],
        staff_id: params[:staff_id], date: params[:date]), **flash
    end

    def redirect_to_edit(**flash)
      redirect_to edit_staff_appointment_path(@appointment, service_id: params[:service_id],
        staff_id: params[:staff_id], date: params[:date]), **flash
    end

    def load_new_appointment_context
      @patients = patient_scope.order(:name, :email)
      @services = @clinic.services.order(:name)
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")

      @patient_id = params[:patient_id].presence
      @service = @services.find_by(id: params[:service_id]) || @services.first
      @staff_id = params.key?(:staff_id) ? params[:staff_id].presence : nil
      @date = parse_date(params[:date])

      @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date).slots : []
    end

    def load_edit_context(appointment)
      @services = @clinic.services.order(:name)
      @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")

      @service = @services.find_by(id: params[:service_id]) || appointment.service
      @staff_id = params.key?(:staff_id) ? params[:staff_id].presence : appointment.staff_id&.to_s
      @date = parse_date(params[:date]) || appointment.starts_at.to_date

      @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date, exclude_appointment_id: appointment.id).slots : []
    end

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
