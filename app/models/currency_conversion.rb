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
class CurrencyConversion < ApplicationRecord
  belongs_to :conference
  validates :rate, numericality: { greater_than: 0 }
  validates :from_currency, uniqueness: { scope: :to_currency }, on: :create
end
