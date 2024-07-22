# frozen_string_literal: true

namespace :data do
  namespace :migrate do
    desc 'Update Currency of past ticket purchases'
    task :update_ticket_purchase_currency do
      TicketPurchase.where(currency: nil).update_all(currency: 'USD')
      TicketPurchase.find_each do |purchase|
        converted_amount = CurrencyConversion.convert_currency(
          purchase.conference,
          purchase.ticket.price_cents,
          purchase.price_currency,
          purchase.currency
        )

        purchase.update_column(:amount_paid_cents, converted_amount)
      end
    end
  end
end
