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
    Availability.delete_all
    Service.delete_all
    ClinicStaff.delete_all
    Clinic.delete_all
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

  # Back to normal per-example transactions for everything below — only the
  # fork-based concurrency test above needs real cross-process commits.
  describe "auto-assigning a doctor for 'Anyone' bookings" do
    self.use_transactional_tests = true

    let(:monday) { Date.current.next_occurring(:monday) }
    let(:starts_at) { monday.in_time_zone.change(hour: 9, min: 0) }

    def book_anyone(patient, starts_at: self.starts_at)
      AppointmentBooking.new(clinic: clinic, params: {
        service_id: service.id, starts_at: starts_at.iso8601
      }).create_for(patient)
    end

    context "when the clinic has not configured any per-staff hours" do
      it "books with no doctor assigned, unchanged from before per-staff availability existed" do
        create(:availability, clinic: clinic, day_of_week: :monday, start_time: "09:00", end_time: "17:00")

        result = book_anyone(create(:user))

        expect(result.success?).to eq(true)
        expect(result.appointment.staff).to be_nil
      end
    end

    context "when the clinic has opted in (at least one per-staff row exists)" do
      def add_doctor(start_time: "09:00", end_time: "17:00", status: :available)
        doctor_user = create(:user)
        clinic_staff = create(:clinic_staff, clinic: clinic, user: doctor_user, status: status)
        create(:availability, clinic: clinic, clinic_staff: clinic_staff, day_of_week: :monday,
          start_time: start_time, end_time: end_time)
        clinic_staff
      end

      it "auto-assigns the only available doctor" do
        doctor = add_doctor

        result = book_anyone(create(:user))

        expect(result.success?).to eq(true)
        expect(result.appointment.staff).to eq(doctor.user)
      end

      it "picks the doctor with fewer existing appointments that day, tie-broken by lowest id" do
        busier = add_doctor
        create(:appointment, clinic: clinic, service: service, staff: busier.user,
          starts_at: monday.in_time_zone.change(hour: 10, min: 0), ends_at: monday.in_time_zone.change(hour: 10, min: 30))
        freer = add_doctor

        result = book_anyone(create(:user))

        expect(result.appointment.staff).to eq(freer.user)
      end

      it "does not auto-assign a doctor who is on_leave" do
        add_doctor(status: :on_leave)
        free_doctor = add_doctor

        result = book_anyone(create(:user))

        expect(result.appointment.staff).to eq(free_doctor.user)
      end

      it "does not auto-assign a doctor whose own hours don't cover that time" do
        add_doctor(start_time: "13:00", end_time: "14:00")

        result = book_anyone(create(:user))

        expect(result.success?).to eq(false)
        expect(result.error).to match(/no doctor is available/i)
      end

      it "fails with a clear message when zero doctors are free at that time, instead of booking unassigned" do
        doctor = add_doctor
        create(:appointment, clinic: clinic, service: service, staff: doctor.user,
          starts_at: starts_at, ends_at: starts_at + 30.minutes)

        result = book_anyone(create(:user))

        expect(result.success?).to eq(false)
        expect(result.error).to match(/no doctor is available/i)
      end
    end
  end
end
