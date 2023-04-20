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
end
