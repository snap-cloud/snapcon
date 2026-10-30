class AddStripeSessionIdToPayments < ActiveRecord::Migration[7.0]
  def change
    add_column :payments, :stripe_session_id, :string
    add_index :payments, :stripe_session_id, unique: true
  end
end
