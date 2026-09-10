class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :clinic, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :status, null: false, default: 0
      t.string :stripe_checkout_session_id, null: false
      t.string :stripe_payment_intent_id

      t.timestamps
    end

    add_index :payments, :stripe_checkout_session_id, unique: true
  end
end
