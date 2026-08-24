class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_clinic

  def show
    load_booking_context
  end

  def create
    result = AppointmentBooking.new(clinic: @clinic, params: params).create_for(current_user)

    if result.success?
      redirect_to root_path, notice: "Your appointment is booked for #{I18n.l(result.appointment.starts_at, format: :long)}."
    else
      redirect_to_booking alert: result.error
    end
  end

  private

  def redirect_to_booking(keep_date: true, **flash)
    redirect_to clinic_booking_path(@clinic, service_id: params[:service_id], month: params[:month],
      date: keep_date ? params[:date] : nil, staff_id: params[:staff_id]), **flash
  end

  def set_clinic
    @clinic = Clinic.find(params[:clinic_id])
  end

  def load_booking_context
    @active_appointment = current_user.patient_appointments.active.order(:starts_at).first
    @editing_appointment = @active_appointment if @active_appointment&.clinic_id == @clinic.id

    @services = @clinic.services.order(:name)
    @service = @services.find_by(id: params[:service_id]) || @editing_appointment&.service || @services.first
    @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
    @staff_id = params.key?(:staff_id) ? params[:staff_id].presence : @editing_appointment&.staff_id&.to_s
    @month = parse_month(params[:month]) || @editing_appointment&.starts_at&.to_date&.beginning_of_month || Date.current.beginning_of_month
    @date = parse_date(params[:date]) || default_edit_date
    @date = nil unless @date && @date.between?(@month, @month.end_of_month)

    @calendar_days = build_calendar_days
    @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date, exclude_appointment_id: @editing_appointment&.id).slots : []
  end

  def default_edit_date
    return nil unless @editing_appointment

    @editing_appointment.starts_at.to_date
  end

  def build_calendar_days
    return [] unless @service

    (@month..@month.end_of_month).map do |day|
      available = day >= Date.current &&
        SlotFinder.new(clinic: @clinic, service: @service, date: day, exclude_appointment_id: @editing_appointment&.id).slots.any?(&:available)
      { date: day, available: available }
    end
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end

  def parse_month(value)
    Date.strptime(value, "%Y-%m").beginning_of_month if value.present?
  rescue ArgumentError
    nil
  end
end
