class CreateClinics < ActiveRecord::Migration[8.1]
  def change
    create_table :clinics do |t|
      t.string :name
      t.string :address
      t.string :phone
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
