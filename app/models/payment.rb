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
#  stripe_session_id  :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  conference_id      :integer          not null
#  user_id            :integer          not null
#
class Payment < ApplicationRecord
  has_many :ticket_purchases
  belongs_to :user
  belongs_to :conference

  validates :status, presence: true
  validates :user_id, presence: true
  validates :conference_id, presence: true
  validates :currency, presence: true

  enum status: {
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

  def unpaid_ticket_purchases
    user.ticket_purchases.unpaid.by_conference(conference)
  end

  def create_checkout_session(success_url:, cancel_url:)
    line_items = build_line_items
    return nil if line_items.empty?

    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      mode:                 'payment',
      customer_email:       user.email,
      line_items:           line_items,
      success_url:          success_url,
      cancel_url:           cancel_url,
      metadata:             {
        payment_id:    id,
        conference_id: conference_id,
        user_id:       user_id
      }
    )

    update(stripe_session_id: session.id)
    session
  rescue Stripe::StripeError => e
    errors.add(:base, e.message)
    self.status = 'failure'
    save
    nil
  end

  def complete_checkout
    session = Stripe::Checkout::Session.retrieve(
      id:     stripe_session_id,
      expand: ['payment_intent.latest_charge']
    )

    if session.payment_status == 'paid'
      charge = session.payment_intent&.latest_charge

      self.amount = session.amount_total
      self.last4 = charge&.payment_method_details&.card&.last4
      self.authorization_code = session.payment_intent&.id
      self.status = 'success'
      save
    else
      self.status = 'failure'
      save
      false
    end
  rescue Stripe::StripeError => e
    errors.add(:base, e.message)
    self.status = 'failure'
    save
    false
  end

  private

  def build_line_items
    unpaid_ticket_purchases.includes(:ticket).map do |tp|
      unit_amount = CurrencyConversion.convert_currency(
        conference, tp.ticket.price, tp.ticket.price_currency, currency
      ).fractional

      {
        price_data: {
          currency:     currency.downcase,
          product_data: {
            name:        tp.title,
            description: tp.description.presence || "#{conference.title} - #{tp.title}"
          },
          unit_amount:  unit_amount
        },
        quantity:   tp.quantity
      }
    end
  end
end
