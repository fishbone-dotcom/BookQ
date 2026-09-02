# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

owner = User.find_or_create_by!(email: "owner@bookq.test") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :staff
end

doctor = User.find_or_create_by!(email: "doctor@bookq.test") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :staff
end

patient = User.find_or_create_by!(email: "patient@bookq.test") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :patient
end

patient2 = User.find_or_create_by!(email: "patient2@bookq.test") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :patient
end

User.find_or_create_by!(email: "admin@bookq.test") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :admin
end

clinic = Clinic.find_or_create_by!(name: "Sunrise Family Clinic") do |c|
  c.owner = owner
  c.address = "123 Rizal Street, Quezon City"
  c.phone = "0917-123-4567"
end

ClinicStaff.find_or_create_by!(clinic: clinic, user: owner) { |cs| cs.role = :owner }
ClinicStaff.find_or_create_by!(clinic: clinic, user: doctor) { |cs| cs.role = :staff }

owner.update!(name: "Dr. Maria Santos")
doctor.update!(name: "Dr. Juan Dela Cruz")

checkup = Service.find_or_create_by!(clinic: clinic, name: "General Check-up") do |s|
  s.duration_minutes = 30
  s.price = 500
end

consultation = Service.find_or_create_by!(clinic: clinic, name: "Follow-up Consultation") do |s|
  s.duration_minutes = 15
  s.price = 300
end

(1..5).each do |day|
  Availability.find_or_create_by!(clinic: clinic, day_of_week: day) do |a|
    a.start_time = "09:00"
    a.end_time = "17:00"
  end
end

# Appointment times below are relative to "now", so a stale one from an
# earlier seed run at a different time won't match find_or_create_by's
# starts_at lookup — clear it first to keep this idempotent.
patient.patient_appointments.active.destroy_all
patient2.patient_appointments.active.destroy_all

# Within the 24-hour reminder window (SendAppointmentRemindersJob) so a seed
# run followed by that job actually produces a sample reminder email.
Appointment.find_or_create_by!(patient: patient, clinic: clinic, service: checkup, staff: doctor,
  starts_at: 18.hours.from_now.change(min: 0)) do |appt|
  appt.ends_at = appt.starts_at + checkup.duration_minutes.minutes
  appt.status = :confirmed
end

# Outside the reminder window, for contrast — should NOT get a reminder yet.
Appointment.find_or_create_by!(patient: patient2, clinic: clinic, service: consultation, staff: doctor,
  starts_at: 2.days.from_now.change(hour: 14, min: 0)) do |appt|
  appt.ends_at = appt.starts_at + consultation.duration_minutes.minutes
  appt.status = :pending
end

patient.update!(name: "Juana Dela Cruz")
patient2.update!(name: "Pedro Reyes")

PatientProfile.find_or_create_by!(user: patient) do |profile|
  profile.birthdate = Date.new(1996, 3, 14)
  profile.sex = "Female"
  profile.phone = "0917-555-1234"
  profile.address = "45 Mabini Street, Quezon City"
  profile.blood_type = "O+"
  profile.allergies = "None"
  profile.emergency_contact_name = "Pedro Dela Cruz"
  profile.emergency_contact_relationship = "Father"
  profile.emergency_contact_phone = "0917-555-5678"
end

PatientProfile.find_or_create_by!(user: patient2) do |profile|
  profile.birthdate = Date.new(1990, 7, 22)
  profile.sex = "Male"
  profile.phone = "0917-555-9876"
  profile.address = "78 Bonifacio Ave, Quezon City"
  profile.blood_type = "A+"
  profile.allergies = "Penicillin"
  profile.emergency_contact_name = "Ana Reyes"
  profile.emergency_contact_relationship = "Spouse"
  profile.emergency_contact_phone = "0917-555-4321"
end

puts "Seeded: #{User.count} users, #{Clinic.count} clinic, #{Service.count} services, #{Appointment.count} appointments"
puts "Log in as owner@bookq.test / doctor@bookq.test / patient@bookq.test / patient2@bookq.test / admin@bookq.test, password: password123"
