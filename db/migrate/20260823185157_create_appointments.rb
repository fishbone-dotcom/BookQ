class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :patient, null: false, foreign_key: { to_table: :users }
      t.references :clinic, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :staff, null: true, foreign_key: { to_table: :users }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :status, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :appointments, [ :clinic_id, :starts_at ]
  end
end
