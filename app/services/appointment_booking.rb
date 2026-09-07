class AppointmentBooking
  Result = Struct.new(:appointment, :success?, :error, keyword_init: true)

  def initialize(clinic:, params:, actor:)
    @clinic = clinic
    @params = params
    @actor = actor
  end

  def create_for(patient)
    return failure("Please select a time first.") if starts_at.blank?
    return failure("You already have an active booking. Only one active booking is allowed per patient.") if patient.patient_appointments.active.exists?
    return failure("No doctor is available at that time — please pick a different one.") if anyone_unavailable?

    save(patient.patient_appointments.build(attributes))
  end

  # Same slot-availability and double-booking protection as `create_for` —
  # both build from the same `attributes`/`anyone_unavailable?`/`save`, so a
  # guest can't bypass anything an authenticated patient is bound by. The
  # one-active-booking-per-patient check `create_for` does up front doesn't
  # apply here (guests have no such global limit — see
  # Appointment#guest_has_no_other_active_appointment_at_clinic instead,
  # which is clinic-scoped and enforced at the model layer via `save` below).
  def create_for_guest(guest_name:, guest_email:, guest_phone:)
    return failure("Please select a time first.") if starts_at.blank?
    return failure("No doctor is available at that time — please pick a different one.") if anyone_unavailable?

    appointment = Appointment.new(attributes.merge(guest_name: guest_name, guest_email: guest_email, guest_phone: guest_phone))
    save(appointment)
  end

  def reschedule(appointment)
    return failure("Please select a time first.") if starts_at.blank?
    return failure("No doctor is available at that time — please pick a different one.") if anyone_unavailable?

    appointment.assign_attributes(attributes)
    save(appointment)
  end

  private

  attr_reader :clinic, :params, :actor

  def attributes
    attrs = {
      clinic: clinic,
      service: service,
      staff: staff,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes
    }
    # Only touch notes when the caller's form actually has a notes field —
    # otherwise reschedule (no notes field on the patient side) would wipe
    # out notes a staffer had already set via the Add Appointment form.
    attrs[:notes] = params[:notes].presence if params.key?(:notes)
    attrs
  end

  def service
    @service ||= clinic.services.find(params[:service_id])
  end

  def staff
    return @staff if defined?(@staff)
    @staff = if params[:staff_id].present?
      clinic.staff_members.find(params[:staff_id])
    elsif per_staff_scheduling_enabled?
      auto_assigned_staff
    end
  end

  # Auto-assignment only kicks in for clinics that have actually configured
  # at least one per-staff schedule — otherwise "Anyone" keeps meaning
  # exactly what it always has (staff_id: nil), unchanged.
  def per_staff_scheduling_enabled?
    clinic.availabilities.where.not(clinic_staff_id: nil).exists?
  end

  # Distinguishes "Anyone, and this clinic hasn't opted into per-staff
  # scheduling" (staff stays nil, booking proceeds as always) from "Anyone,
  # opted in, but genuinely nobody is free at that time" (should fail rather
  # than silently book with no doctor assigned).
  def anyone_unavailable?
    params[:staff_id].blank? && per_staff_scheduling_enabled? && staff.nil?
  end

  def auto_assigned_staff
    return nil if starts_at.blank?

    finder = SlotFinder.new(clinic: clinic, service: service, date: starts_at.to_date)
    candidates = finder.available_staff_for(starts_at, starts_at + service.duration_minutes.minutes)
    candidates.min_by { |cs| [ appointment_count_for(cs), cs.id ] }&.user
  end

  def appointment_count_for(clinic_staff)
    clinic.appointments.active.where(staff_id: clinic_staff.user_id, starts_at: starts_at.to_date.all_day).count
  end

  def starts_at
    return @starts_at if defined?(@starts_at)
    @starts_at = Time.zone.parse(params[:starts_at]) if params[:starts_at].present?
  rescue ArgumentError
    @starts_at = nil
  end

  def save(appointment)
    appointment.audit_actor = actor
    if appointment.save
      Result.new(appointment: appointment, success?: true)
    else
      Result.new(appointment: appointment, success?: false,
        error: appointment.errors.full_messages.to_sentence.presence || "Someone else just booked that time — please pick a different one.")
    end
  end

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
