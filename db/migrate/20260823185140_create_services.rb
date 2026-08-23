class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :clinic, null: false, foreign_key: true
      t.string :name
      t.integer :duration_minutes
      t.decimal :price, precision: 8, scale: 2

      t.timestamps
    end
  end
end
