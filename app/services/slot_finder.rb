class SlotFinder
  Slot = Struct.new(:starts_at, :ends_at, :available, keyword_init: true)

  def initialize(clinic:, service:, date:, exclude_appointment_id: nil)
    @clinic = clinic
    @service = service
    @date = date
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
      slots << Slot.new(
        starts_at: slot_start,
        ends_at: slot_end,
        available: slot_start > Time.current && !overlaps_booked?(slot_start, slot_end)
      )
      slot_start = slot_end
    end
    slots
  end

  private

  attr_reader :clinic, :service, :date, :exclude_appointment_id

  def availability
    @availability ||= clinic.availabilities.find_by(day_of_week: date.wday)
  end

  def booked_ranges
    @booked_ranges ||= begin
      scope = clinic.appointments
        .where(starts_at: date.in_time_zone.beginning_of_day..date.in_time_zone.end_of_day)
        .where.not(status: :cancelled)
      scope = scope.where.not(id: exclude_appointment_id) if exclude_appointment_id
      scope.pluck(:starts_at, :ends_at)
    end
  end

  def overlaps_booked?(slot_start, slot_end)
    booked_ranges.any? { |booked_start, booked_end| slot_start < booked_end && slot_end > booked_start }
  end
end
