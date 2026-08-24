class AppointmentBooking
  Result = Struct.new(:appointment, :success?, :error, keyword_init: true)

  def initialize(clinic:, params:)
    @clinic = clinic
    @params = params
  end

  def create_for(patient)
    return failure("Please select a time first.") if starts_at.blank?
    return failure("You already have an active booking. Only one active booking is allowed per patient.") if patient.patient_appointments.active.exists?

    save(patient.patient_appointments.build(attributes))
  end

  def reschedule(appointment)
    return failure("Please select a time first.") if starts_at.blank?

    appointment.assign_attributes(attributes)
    save(appointment)
  end

  private

  attr_reader :clinic, :params

  def attributes
    {
      clinic: clinic,
      service: service,
      staff: staff,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes
    }
  end

  def service
    @service ||= clinic.services.find(params[:service_id])
  end

  def staff
    return @staff if defined?(@staff)
    @staff = params[:staff_id].present? ? clinic.staff_members.find(params[:staff_id]) : nil
  end

  def starts_at
    return @starts_at if defined?(@starts_at)
    @starts_at = Time.zone.parse(params[:starts_at]) if params[:starts_at].present?
  rescue ArgumentError
    @starts_at = nil
  end

  def save(appointment)
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
