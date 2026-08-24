class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_clinic

  def show
    load_booking_context
  end

  def create
    service = @clinic.services.find(params[:service_id])

    if current_user.patient_appointments.active.exists?
      return redirect_to_booking alert: "May aktibo ka nang booking. Isang aktibong booking lang ang pinapayagan kada patient."
    end

    starts_at = parse_time(params[:starts_at])
    return redirect_to_booking alert: "Pumili muna ng oras." if starts_at.blank?

    staff = params[:staff_id].present? ? @clinic.staff_members.find(params[:staff_id]) : nil
    appointment = current_user.patient_appointments.build(
      clinic: @clinic,
      service: service,
      staff: staff,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending
    )

    if appointment.save
      redirect_to_booking notice: "Na-book na ang appointment mo sa #{I18n.l(appointment.starts_at, format: :long)}.", keep_date: false
    else
      redirect_to_booking alert: appointment.errors.full_messages.to_sentence.presence || "Naunahan ka na — nabook na ng iba ang oras na 'yan."
    end
  end

  private

  def redirect_to_booking(keep_date: true, **flash)
    redirect_to clinic_booking_path(@clinic, service_id: params[:service_id], month: params[:month],
      date: keep_date ? params[:date] : nil), **flash
  end

  def set_clinic
    @clinic = Clinic.find(params[:clinic_id])
  end

  def load_booking_context
    @active_appointment = current_user.patient_appointments.active.order(:starts_at).first
    @services = @clinic.services.order(:name)
    @service = @services.find_by(id: params[:service_id]) || @services.first
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    @date = parse_date(params[:date])
    @date = nil unless @date && @date.between?(@month, @month.end_of_month)

    @calendar_days = build_calendar_days
    @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date).slots : []
  end

  def build_calendar_days
    return [] unless @service

    (@month..@month.end_of_month).map do |day|
      available = day >= Date.current && SlotFinder.new(clinic: @clinic, service: @service, date: day).slots.any?(&:available)
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

  def parse_time(value)
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
