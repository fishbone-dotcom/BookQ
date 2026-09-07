class DoctorUnavailability
  Result = Struct.new(:cancelled_count, keyword_init: true)

  def initialize(clinic:, clinic_staff:, from_date:, to_date:)
    @clinic = clinic
    @clinic_staff = clinic_staff
    @from_date = from_date
    @to_date = to_date
  end

  def apply!
    count = 0
    affected_appointments.find_each do |appointment|
      appointment.cancel!
      AppointmentMailer.staff_unavailable(appointment).deliver_later
      count += 1
    end
    Result.new(cancelled_count: count)
  end

  private

  attr_reader :clinic, :clinic_staff, :from_date, :to_date

  def affected_appointments
    clinic.appointments.active
      .where(staff_id: clinic_staff.user_id)
      .where(starts_at: from_date.beginning_of_day..to_date.end_of_day)
      .where("starts_at > ?", Time.current)
  end
end
