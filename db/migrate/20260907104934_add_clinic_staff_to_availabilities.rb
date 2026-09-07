class AddClinicStaffToAvailabilities < ActiveRecord::Migration[8.1]
  def change
    # Nullable: nil means "clinic-wide default hours" (every existing row),
    # a real id means a specific staff member's override for that day.
    add_reference :availabilities, :clinic_staff, null: true, foreign_key: true
    add_index :availabilities, [ :clinic_id, :clinic_staff_id, :day_of_week ],
      unique: true, name: "index_availabilities_on_clinic_staff_and_day"
  end
end
