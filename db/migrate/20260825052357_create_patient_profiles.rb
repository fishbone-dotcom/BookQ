class CreatePatientProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :patient_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.date :birthdate
      t.string :sex
      t.string :phone
      t.string :address
      t.string :blood_type
      t.text :allergies
      t.string :emergency_contact_name
      t.string :emergency_contact_relationship
      t.string :emergency_contact_phone

      t.timestamps
    end
  end
end
