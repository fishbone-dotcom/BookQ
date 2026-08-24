# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_24_060811) do
  create_table "appointments", force: :cascade do |t|
    t.integer "clinic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.text "notes"
    t.integer "patient_id", null: false
    t.integer "service_id", null: false
    t.integer "staff_id"
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["clinic_id", "starts_at"], name: "index_appointments_on_clinic_id_and_starts_at"
    t.index ["clinic_id"], name: "index_appointments_on_clinic_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.index ["service_id"], name: "index_appointments_on_service_id"
    t.index ["staff_id"], name: "index_appointments_on_staff_id"
  end

  create_table "availabilities", force: :cascade do |t|
    t.integer "clinic_id", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.time "end_time"
    t.time "start_time"
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_availabilities_on_clinic_id"
  end

  create_table "clinic_staffs", force: :cascade do |t|
    t.integer "clinic_id", null: false
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["clinic_id", "user_id"], name: "index_clinic_staffs_on_clinic_id_and_user_id", unique: true
    t.index ["clinic_id"], name: "index_clinic_staffs_on_clinic_id"
    t.index ["user_id"], name: "index_clinic_staffs_on_user_id"
  end

  create_table "clinics", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "owner_id", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_clinics_on_owner_id"
  end

  create_table "services", force: :cascade do |t|
    t.integer "clinic_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.string "name"
    t.decimal "price", precision: 8, scale: 2
    t.datetime "updated_at", null: false
    t.index ["clinic_id"], name: "index_services_on_clinic_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "appointments", "clinics"
  add_foreign_key "appointments", "services"
  add_foreign_key "appointments", "users", column: "patient_id"
  add_foreign_key "appointments", "users", column: "staff_id"
  add_foreign_key "availabilities", "clinics"
  add_foreign_key "clinic_staffs", "clinics"
  add_foreign_key "clinic_staffs", "users"
  add_foreign_key "clinics", "users", column: "owner_id"
  add_foreign_key "services", "clinics"
end
