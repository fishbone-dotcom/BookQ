class BookingsController < ApplicationController
  before_action :set_clinic, except: :payment_return

  def show
    load_booking_context
  end

  def create
    if user_signed_in?
      result = AppointmentBooking.new(clinic: @clinic, params: params, actor: current_user).create_for(current_user)
      return redirect_to_booking(alert: result.error) unless result.success?
    else
      result = AppointmentBooking.new(clinic: @clinic, params: params, actor: nil).create_for_guest(
        guest_name: params[:guest_name], guest_email: params[:guest_email], guest_phone: params[:guest_phone]
      )
      return redirect_to_booking(alert: result.error) unless result.success?
    end

    redirect_after_booking(result.appointment)
  end

  # Landing point for Stripe's Checkout success_url — reconciles immediately
  # so the user doesn't have to wait on webhook delivery to see confirmation.
  # The (unguessable) Stripe session id is the capability token here, since a
  # guest has no session to check ownership against.
  def payment_return
    payment = Payment.find_by!(stripe_checkout_session_id: params[:session_id])
    session = Stripe::Checkout::Session.retrieve(payment.stripe_checkout_session_id)
    payment.mark_paid!(payment_intent_id: session.payment_intent) if session.payment_status == "paid"

    redirect_after_booking(payment.appointment.reload)
  end

  private

  def redirect_after_booking(appointment)
    if appointment.cancelled?
      redirect_to root_path, alert: "This booking was cancelled because payment wasn't completed in time."
    elsif appointment.payment_required? && !appointment.payment&.paid?
      return redirect_to root_path, alert: "Payment is still pending — please complete checkout." if appointment.payment&.pending?

      checkout = AppointmentCheckout.create_for(appointment,
        success_url: booking_payment_return_url(session_id: "{CHECKOUT_SESSION_ID}"),
        cancel_url: clinic_booking_url(appointment.clinic, alert: "Payment cancelled — your slot was released."))
      return redirect_to_booking(alert: checkout.error) unless checkout.success?

      redirect_to checkout.checkout_url, allow_other_host: true
    elsif appointment.patient.present?
      redirect_to root_path, notice: "Your appointment is booked for #{I18n.l(appointment.starts_at, format: :long)}."
    else
      AppointmentMailer.confirmation(appointment).deliver_later unless appointment.payment_required?
      redirect_to guest_appointment_path(appointment.signed_id(purpose: :guest_management, expires_in: 60.days)),
        notice: "Appointment confirmed!"
    end
  end

  def redirect_to_booking(keep_date: true, **flash)
    redirect_to clinic_booking_path(@clinic, service_id: params[:service_id], month: params[:month],
      date: keep_date ? params[:date] : nil, staff_id: params[:staff_id]), **flash
  end

  def set_clinic
    @clinic = Clinic.find(params[:clinic_id])
  end

  def load_booking_context
    @active_appointment = current_user&.patient_appointments&.active&.order(:starts_at)&.first
    @editing_appointment = @active_appointment if @active_appointment&.clinic_id == @clinic.id

    @services = @clinic.services.order(:name)
    @service = @services.find_by(id: params[:service_id]) || @editing_appointment&.service || @services.first
    @clinic_staffs = @clinic.clinic_staffs.includes(:user).joins(:user).order("users.name")
    @staff_id = params.key?(:staff_id) ? params[:staff_id].presence : @editing_appointment&.staff_id&.to_s
    @month = parse_month(params[:month]) || @editing_appointment&.starts_at&.to_date&.beginning_of_month || Date.current.beginning_of_month
    @date = parse_date(params[:date]) || default_edit_date
    @date = nil unless @date && @date.between?(@month, @month.end_of_month)

    @calendar_days = build_calendar_days
    @slots = @service && @date ? SlotFinder.new(clinic: @clinic, service: @service, date: @date,
      staff: selected_staff, exclude_appointment_id: @editing_appointment&.id).slots : []
  end

  # The specific doctor the patient picked, if any — nil means "Anyone",
  # which SlotFinder treats as clinic-wide hours (per-staff scheduling has no
  # single doctor to check yet at this point in the wizard).
  def selected_staff
    return @selected_staff if defined?(@selected_staff)
    @selected_staff = @staff_id.present? ? @clinic.staff_members.find_by(id: @staff_id) : nil
  end

  def default_edit_date
    return nil unless @editing_appointment

    @editing_appointment.starts_at.to_date
  end

  def build_calendar_days
    return [] unless @service

    (@month..@month.end_of_month).map do |day|
      available = day >= Date.current &&
        SlotFinder.new(clinic: @clinic, service: @service, date: day, staff: selected_staff,
          exclude_appointment_id: @editing_appointment&.id).slots.any?(&:available)
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
