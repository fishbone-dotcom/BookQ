require "rails_helper"

RSpec.describe SendAppointmentRemindersJob, type: :job do
  include ActiveJob::TestHelper

  def build_appointment(starts_at:, status: :pending, reminder_sent_at: nil)
    create(:appointment,
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      status: status,
      reminder_sent_at: reminder_sent_at)
  end

  it "sends a reminder for an active appointment starting within 24 hours" do
    appointment = build_appointment(starts_at: 12.hours.from_now)

    expect { perform_enqueued_jobs { described_class.perform_now } }
      .to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(appointment.reload.reminder_sent_at).to be_present
  end

  it "does not send a reminder for an appointment more than 24 hours away" do
    build_appointment(starts_at: 2.days.from_now)

    expect { perform_enqueued_jobs { described_class.perform_now } }
      .not_to(change { ActionMailer::Base.deliveries.count })
  end

  it "does not send a reminder for an appointment that already started" do
    build_appointment(starts_at: 1.hour.ago)

    expect { perform_enqueued_jobs { described_class.perform_now } }
      .not_to(change { ActionMailer::Base.deliveries.count })
  end

  it "does not send a reminder for a cancelled appointment" do
    build_appointment(starts_at: 12.hours.from_now, status: :cancelled)

    expect { perform_enqueued_jobs { described_class.perform_now } }
      .not_to(change { ActionMailer::Base.deliveries.count })
  end

  it "does not send a duplicate reminder" do
    build_appointment(starts_at: 12.hours.from_now, reminder_sent_at: 1.hour.ago)

    expect { perform_enqueued_jobs { described_class.perform_now } }
      .not_to(change { ActionMailer::Base.deliveries.count })
  end
end
