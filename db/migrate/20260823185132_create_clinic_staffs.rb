class CreateClinicStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :clinic_staffs do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, default: 0, null: false

      t.timestamps
    end

    add_index :clinic_staffs, [ :clinic_id, :user_id ], unique: true
  end
end
