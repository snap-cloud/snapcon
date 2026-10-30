# frozen_string_literal: true

# == Schema Information
#
# Table name: payments
#
#  id                 :bigint           not null, primary key
#  amount             :integer
#  authorization_code :string
#  currency           :string
#  last4              :string
#  status             :integer          default("unpaid"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  conference_id      :integer          not null
#  stripe_session_id  :string
#  user_id            :integer          not null
#
# Indexes
#
#  index_payments_on_stripe_session_id  (stripe_session_id) UNIQUE
#
FactoryBot.define do
  factory :payment do
    user
    conference
    status { 'unpaid' }
    currency { 'USD' }
  end
end
