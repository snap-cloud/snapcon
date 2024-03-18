class AddDefaultCurrencyToPayments < ActiveRecord::Migration[7.0]
  def change
    change_column_default :payments, :currency, from: nil, to: 'USD'
    change_column_default :ticket_purchases, :currency, from: nil, to: 'USD'
  end
end
