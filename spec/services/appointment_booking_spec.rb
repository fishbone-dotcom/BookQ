require "rails_helper"

RSpec.describe AppointmentBooking, type: :model do
  # A real concurrency test needs each attempt to hold its own DB
  # transaction. Ruby threads share the GIL and MRI's sqlite3 gem doesn't
  # release it around these (very fast, local-file) queries, so two threads
  # never actually interleave here — the race window only opens across
  # separate OS processes, which is also how Puma achieves real concurrency
  # in production. Fork real child processes instead.
  #
  # This also needs real commits to be visible across processes, which the
  # default per-example transaction wrapper (rolled back after each test)
  # would prevent.
  self.use_transactional_tests = false

  let(:clinic) { create(:clinic) }
  let(:service) { create(:service, clinic: clinic, duration_minutes: 30) }

  after do
    Appointment.delete_all
    Service.delete_all
    Clinic.delete_all
    ClinicStaff.delete_all
    User.delete_all
  end

  it "prevents two simultaneous requests from double-booking the same slot" do
    # Force these to be created (and committed) in the parent *before*
    # forking. Left as lazy `let`s, each child would independently trigger
    # its own `create(:clinic)` the first time it's referenced post-fork —
    # two different clinics, not a race on the same one.
    booking_clinic = clinic
    booking_service = service
    patient_a = create(:user)
    patient_b = create(:user)
    starts_at = 1.day.from_now.change(hour: 10, min: 0)

    ActiveRecord::Base.connection_handler.clear_active_connections!

    # fork() itself takes long enough that, without a barrier, the first
    # child reliably finishes its whole booking flow before the second one
    # is even scheduled — no overlap, no race. Hold both children at a gate
    # right before the booking call and release them together.
    gate_r, gate_w = IO.pipe

    pids_and_pipes = [ patient_a, patient_b ].map do |patient|
      reader, writer = IO.pipe
      pid = fork do
        reader.close
        gate_w.close
        ActiveRecord::Base.connection_handler.clear_active_connections!

        gate_r.read(1)

        result = AppointmentBooking.new(clinic: booking_clinic, params: {
          service_id: booking_service.id,
          starts_at: starts_at.iso8601
        }).create_for(patient)

        writer.write(result.success? ? "1" : "0")
        writer.close
        exit!(0)
      end
      writer.close
      [ pid, reader ]
    end

    gate_r.close
    gate_w.write("go")
    gate_w.close

    outcomes = pids_and_pipes.map do |pid, reader|
      outcome = reader.read
      reader.close
      Process.wait(pid)
      outcome
    end

    expect(outcomes.count("1")).to eq(1)
    expect(Appointment.where(clinic: booking_clinic, starts_at: starts_at).count).to eq(1)
  end
end
