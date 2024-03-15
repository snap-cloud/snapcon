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
FactoryBot.define do
  factory :currency_conversion do
    from_currency { 'USD' }
    to_currency { 'EUR' }
    rate { 0.89 }
    conference
  end
end
