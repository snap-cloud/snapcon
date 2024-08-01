class SetCurrencyForNullTicketPurchaseCurrency < ActiveRecord::Migration[7.0]
  def up
    # TicketPurchase.where(currency: nil).update_all(currency: 'USD')
  end
end
