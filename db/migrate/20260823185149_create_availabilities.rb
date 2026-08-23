class CreateAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :availabilities do |t|
      t.references :clinic, null: false, foreign_key: true
      t.integer :day_of_week
      t.time :start_time
      t.time :end_time

      t.timestamps
    end
  end
end
