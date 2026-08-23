class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_clinic

  def show
    @services = @clinic.services.order(:name)
    @service = @services.find_by(id: params[:service_id]) || @services.first
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    @date = parse_date(params[:date])
    @date = nil unless @date && @date.between?(@month, @month.end_of_month)

    @calendar_days = build_calendar_days
    @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date).slots : []
  end

  def create
    service = @clinic.services.find(params[:service_id])
    starts_at = parse_time(params[:starts_at])
    staff = params[:staff_id].present? ? @clinic.staff_members.find(params[:staff_id]) : nil

    appointment = current_user.patient_appointments.build(
      clinic: @clinic,
      service: service,
      staff: staff,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending
    )

    redirect_params = { month: params[:month], date: params[:date], service_id: service.id }

    if starts_at.present? && appointment.save
      redirect_to clinic_booking_path(@clinic, redirect_params),
        notice: "Appointment booked for #{I18n.l(appointment.starts_at, format: :long)}"
    else
      redirect_to clinic_booking_path(@clinic, redirect_params),
        alert: appointment.errors.full_messages.to_sentence.presence || "Hindi na available ang oras na 'yan."
    end
  end

  private

  def set_clinic
    @clinic = Clinic.find(params[:clinic_id])
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
