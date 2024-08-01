class AddAmountPaidCentsToTicketPurchases < ActiveRecord::Migration[7.0]
  def up
    add_column :ticket_purchases, :amount_paid_cents, :integer, default: 0

    TicketPurchase.reset_column_information
  end

  def down
    # Remove the amount_paid_cents column if you roll back this migration
    remove_column :ticket_purchases, :amount_paid_cents
  end
end
