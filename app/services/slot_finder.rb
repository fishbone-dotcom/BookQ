class SlotFinder
  Slot = Struct.new(:starts_at, :ends_at, :available, keyword_init: true)

  def initialize(clinic:, service:, date:, staff: nil, exclude_appointment_id: nil)
    @clinic = clinic
    @service = service
    @date = date
    @staff = staff
    @exclude_appointment_id = exclude_appointment_id
  end

  def slots
    return [] if availability.nil?

    duration = service.duration_minutes.minutes
    day_start = date.in_time_zone.change(hour: availability.start_time.hour, min: availability.start_time.min)
    day_end = date.in_time_zone.change(hour: availability.end_time.hour, min: availability.end_time.min)

    slots = []
    slot_start = day_start
    while slot_start + duration <= day_end
      slot_end = slot_start + duration
      slots << Slot.new(starts_at: slot_start, ends_at: slot_end, available: slot_available?(slot_start, slot_end))
      slot_start = slot_end
    end
    slots
  end

  # Which of the clinic's (currently-available, i.e. not on_leave) staff are
  # actually free for this exact slot — right hours AND not already booked.
  # Used to auto-assign a doctor when a patient picks "Anyone".
  def available_staff_for(slot_starts_at, slot_ends_at)
    clinic.clinic_staffs.available.select do |clinic_staff|
      self.class.new(clinic: clinic, service: service, date: date, staff: clinic_staff.user,
        exclude_appointment_id: exclude_appointment_id).slot_available?(slot_starts_at, slot_ends_at)
    end
  end

  def slot_available?(slot_start, slot_end)
    slot_start > Time.current && !availability.nil? && within_hours?(slot_start, slot_end) && !overlaps_booked?(slot_start, slot_end)
  end

  private

  attr_reader :clinic, :service, :date, :staff, :exclude_appointment_id

  def within_hours?(slot_start, slot_end)
    day_start = date.in_time_zone.change(hour: availability.start_time.hour, min: availability.start_time.min)
    day_end = date.in_time_zone.change(hour: availability.end_time.hour, min: availability.end_time.min)
    slot_start >= day_start && slot_end <= day_end
  end

  # Staff-specific hours if the staff member has their own override for this
  # day, otherwise fall back to the clinic's default hours for that day. With
  # no staff given, only the clinic-wide row is ever considered — unchanged
  # from before per-staff availability existed.
  def availability
    @availability ||= if staff.present?
      clinic_staff_id = clinic.clinic_staffs.find_by(user_id: staff.id)&.id
      clinic.availabilities.find_by(clinic_staff_id: clinic_staff_id, day_of_week: date.wday) ||
        clinic.availabilities.find_by(clinic_staff_id: nil, day_of_week: date.wday)
    else
      clinic.availabilities.find_by(clinic_staff_id: nil, day_of_week: date.wday)
    end
  end

  def booked_ranges
    @booked_ranges ||= begin
      scope = clinic.appointments
        .where(starts_at: date.in_time_zone.beginning_of_day..date.in_time_zone.end_of_day)
        .where.not(status: :cancelled)
      scope = scope.where(staff_id: staff.id) if staff.present?
      scope = scope.where.not(id: exclude_appointment_id) if exclude_appointment_id
      scope.pluck(:starts_at, :ends_at)
    end
  end

  def overlaps_booked?(slot_start, slot_end)
    booked_ranges.any? { |booked_start, booked_end| slot_start < booked_end && slot_end > booked_start }
  end
end
