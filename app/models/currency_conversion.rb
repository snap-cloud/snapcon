# frozen_string_literal: true

# == Schema Information
#
# Table name: currency_conversions
#
#  id            :bigint           not null, primary key
#  from_currency :string
#  rate          :decimal(, )
#  to_currency   :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  conference_id :bigint           not null
#
# Indexes
#
#  index_currency_conversions_on_conference_id  (conference_id)
#
# Foreign Keys
#
#  fk_rails_...  (conference_id => conferences.id)
#
class CurrencyConversion < ApplicationRecord
  VALID_CURRENCIES = %w[AUD CAD CHF CNY EUR GBP JPY USD].freeze
  belongs_to :conference
  validates :rate, numericality: { greater_than: 0 }
  validates :from_currency, uniqueness: { scope: :to_currency }, on: :create

  def self.convert_currency(conference, amount, from_currency, to_currency)
    conversion = conference.currency_conversions.find_by(from_currency: from_currency, to_currency: to_currency)

    if conversion
      Money.add_rate(from_currency, to_currency, conversion.rate)
    else
      # If no conversion is found. Typically only possible if base to base. Maybe make this error out.
      Money.add_rate(from_currency, to_currency, 1) unless from_currency == to_currency
    end

    # money_amount = Money.from_amount(amount, from_currency)
    amount.exchange_to(to_currency)
  end
end
