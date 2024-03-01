# frozen_string_literal: true

# == Schema Information
#
# Table name: currency_conversions
#
#  rate          :decimal
#  from_currency :string
#  to_currency   :string
#  conference_id :integer
#
FactoryBot.define do
  factory :currency_conversion do
    from_currency { 'USD' }
    to_currency { 'EUR' }
    rate { 0.89 }
    conference
  end
end
