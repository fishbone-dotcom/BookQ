class AddGuestFieldsToAppointments < ActiveRecord::Migration[8.1]
  def change
    change_column_null :appointments, :patient_id, true
    add_column :appointments, :guest_name, :string
    add_column :appointments, :guest_email, :string
    add_column :appointments, :guest_phone, :string
    add_index :appointments, :guest_email
  end
end
