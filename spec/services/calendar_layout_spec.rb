require "rails_helper"

RSpec.describe CalendarLayout do
  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }
  let(:day) { Date.current + 3.days }

  def appointment_at(hour, min = 0, duration = 30, staff: nil)
    starts_at = day.in_time_zone.change(hour: hour, min: min)
    create(:appointment, clinic: clinic, service: service, staff: staff,
      starts_at: starts_at, ends_at: starts_at + duration.minutes)
  end

  it "gives non-overlapping appointments their own full-width column" do
    morning = appointment_at(9)
    afternoon = appointment_at(14)

    placements = described_class.new([ morning, afternoon ]).placements
    by_appointment = placements.index_by(&:appointment)

    expect(by_appointment[morning].column).to eq(0)
    expect(by_appointment[morning].columns).to eq(1)
    expect(by_appointment[afternoon].column).to eq(0)
    expect(by_appointment[afternoon].columns).to eq(1)
  end

  it "places two overlapping appointments side by side" do
    staff_a = create(:user)
    staff_b = create(:user)
    first = appointment_at(9, 0, 30, staff: staff_a)
    second = appointment_at(9, 15, 30, staff: staff_b)

    placements = described_class.new([ first, second ]).placements
    by_appointment = placements.index_by(&:appointment)

    expect(by_appointment[first].columns).to eq(2)
    expect(by_appointment[second].columns).to eq(2)
    expect(by_appointment[first].column).not_to eq(by_appointment[second].column)
  end

  it "does not let an earlier overlap cluster inflate the column count of a later, separate cluster" do
    staff_a = create(:user)
    staff_b = create(:user)
    morning_1 = appointment_at(9, 0, 30, staff: staff_a)
    morning_2 = appointment_at(9, 15, 30, staff: staff_b)
    afternoon_solo = appointment_at(14)

    placements = described_class.new([ morning_1, morning_2, afternoon_solo ]).placements
    by_appointment = placements.index_by(&:appointment)

    expect(by_appointment[morning_1].columns).to eq(2)
    expect(by_appointment[afternoon_solo].columns).to eq(1)
    expect(by_appointment[afternoon_solo].column).to eq(0)
  end

  it "reuses a freed column once an earlier appointment in the cluster has ended" do
    staff_a = create(:user)
    staff_b = create(:user)
    staff_c = create(:user)
    first = appointment_at(9, 0, 15, staff: staff_a)   # 9:00-9:15
    second = appointment_at(9, 0, 15, staff: staff_b)  # 9:00-9:15, overlaps first
    third = appointment_at(9, 15, 15, staff: staff_c)  # 9:15-9:30, only overlaps the cluster's end boundary

    placements = described_class.new([ first, second, third ]).placements
    by_appointment = placements.index_by(&:appointment)

    expect(by_appointment[first].columns).to eq(2)
    expect(by_appointment[third].column).to eq(0)
  end
end
