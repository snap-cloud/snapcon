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
end
