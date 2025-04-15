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
#  user_id            :integer          not null
#
class Payment < ApplicationRecord
  has_many :ticket_purchases
  belongs_to :user
  belongs_to :conference

  attr_accessor :stripe_customer_email, :stripe_customer_token

  validates :status, presence: true
  validates :user_id, presence: true
  validates :conference_id, presence: true
  validates :currency, presence: true

  enum :status, {
    unpaid:  0,
    success: 1,
    failure: 2
  }

  def amount_to_pay
    CurrencyConversion.convert_currency(conference, Ticket.total_price(conference, user, paid: false), conference.tickets.first.price_currency, currency).cents
  end

  def stripe_description
    "Tickets for #{conference.title} #{user.name} #{user.email}"
  end

  def purchase
    gateway_response = Stripe::Charge.create source:        stripe_customer_token,
                                             receipt_email: stripe_customer_email,
                                             description:   stripe_description,
                                             amount:        amount_to_pay,
                                             currency:      currency

    self.amount = gateway_response[:amount]
    self.last4 = gateway_response[:source][:last4]
    self.authorization_code = gateway_response[:id]
    self.status = 'success'
    true
  rescue Stripe::StripeError => e
    errors.add(:base, e.message)
    self.status = 'failure'
    false
  end
end
