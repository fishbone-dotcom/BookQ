class CreateAppointmentAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_audits do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.integer :action, null: false
      t.string :reason
      t.datetime :previous_starts_at

      t.timestamps
    end
  end
end
