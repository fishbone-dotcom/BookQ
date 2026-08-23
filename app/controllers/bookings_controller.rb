class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_clinic

  def show
    @services = @clinic.services.order(:name)
    @service = @services.find_by(id: params[:service_id]) || @services.first
    @date = parse_date(params[:date]) || Date.current
    @slots = @service ? SlotFinder.new(clinic: @clinic, service: @service, date: @date).slots : []
  end

  def create
    service = @clinic.services.find(params[:service_id])
    starts_at = parse_time(params[:starts_at])

    appointment = current_user.patient_appointments.build(
      clinic: @clinic,
      service: service,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending
    )

    if starts_at.present? && appointment.save
      redirect_to clinic_booking_path(@clinic, date: starts_at.to_date.iso8601, service_id: service.id),
        notice: "Appointment booked for #{I18n.l(appointment.starts_at, format: :long)}"
    else
      redirect_to clinic_booking_path(@clinic, date: params[:date], service_id: service.id),
        alert: appointment.errors.full_messages.to_sentence.presence || "Hindi na available ang oras na 'yan."
    end
  end

  private

  def set_clinic
    @clinic = Clinic.find(params[:clinic_id])
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end

  def parse_time(value)
    Time.zone.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
