class AddAmountPaidCentsToTicketPurchases < ActiveRecord::Migration[7.0]
  def up
    add_column :ticket_purchases, :amount_paid_cents, :integer, default: 0

    TicketPurchase.reset_column_information

    TicketPurchase.find_each do |purchase|
      converted_amount = CurrencyConversion.convert_currency(
        purchase.conference, 
        purchase.price, 
        purchase.price_currency, 
        purchase.currency  
      )

      purchase.update_column(:amount_paid_cents, converted_amount.fractional)
    end
  end

  def down
    # Remove the amount_paid_cents column if you roll back this migration
    remove_column :ticket_purchases, :amount_paid_cents
  end
end
