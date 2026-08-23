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

clinic = Clinic.find_or_create_by!(name: "Sunrise Family Clinic") do |c|
  c.owner = owner
  c.address = "123 Rizal Street, Quezon City"
  c.phone = "0917-123-4567"
end

ClinicStaff.find_or_create_by!(clinic: clinic, user: owner) { |cs| cs.role = :owner }
ClinicStaff.find_or_create_by!(clinic: clinic, user: doctor) { |cs| cs.role = :staff }

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

Appointment.find_or_create_by!(patient: patient, clinic: clinic, service: checkup, staff: doctor,
  starts_at: 1.day.from_now.change(hour: 10, min: 0)) do |appt|
  appt.ends_at = appt.starts_at + checkup.duration_minutes.minutes
  appt.status = :confirmed
end

Appointment.find_or_create_by!(patient: patient, clinic: clinic, service: consultation, staff: doctor,
  starts_at: 2.days.from_now.change(hour: 14, min: 0)) do |appt|
  appt.ends_at = appt.starts_at + consultation.duration_minutes.minutes
  appt.status = :pending
end

puts "Seeded: #{User.count} users, #{Clinic.count} clinic, #{Service.count} services, #{Appointment.count} appointments"
puts "Log in as owner@bookq.test / doctor@bookq.test / patient@bookq.test, password: password123"
