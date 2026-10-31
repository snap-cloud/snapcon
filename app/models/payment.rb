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
class Payment < ApplicationRecord
  has_many :ticket_purchases
  belongs_to :user
  belongs_to :conference

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

  def unpaid_ticket_purchases
    user.ticket_purchases.unpaid.by_conference(conference)
  end

  # Starts a Stripe Checkout session for the user's unpaid tickets and links
  # those ticket purchases to this payment. Only linked purchases are marked
  # paid when the checkout completes, so tickets added later aren't included.
  def create_checkout_session(success_url:, cancel_url:)
    settle_other_pending_checkouts

    purchases = unpaid_ticket_purchases.includes(:ticket).to_a
    line_items = build_line_items(purchases)
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

    transaction do
      update!(stripe_session_id: session.id, amount: line_items_total(line_items))
      TicketPurchase.where(id: purchases.map(&:id)).update_all(payment_id: id)
    end
    session
  rescue Stripe::StripeError => e
    self.status = 'failure'
    save
    errors.add(:base, e.message)
    nil
  end

  # Confirms the Checkout session with Stripe and marks this payment's linked
  # ticket purchases as paid. Safe to call more than once (the success page and
  # the webhook both call it). Returns one of:
  #   :fulfilled          - paid; tickets marked paid now
  #   :already_fulfilled  - paid; tickets were marked paid by an earlier call
  #   :not_paid           - Stripe hasn't received payment for this session
  #   :mismatch           - paid, but the amount doesn't match the linked tickets
  #   :error              - Stripe API error
  def fulfill_checkout
    result = nil
    # Lock the row so the success page and the webhook can't both fulfill it.
    with_lock { result = fulfill_checkout_locked }
    result
  rescue Stripe::StripeError => e
    errors.add(:base, e.message)
    Rails.logger.error("Stripe error completing payment #{id}: #{e.message}")
    :error
  end

  private

  def fulfill_checkout_locked
    return :already_fulfilled if success?
    return :mismatch if failure? && authorization_code.present?
    return :not_paid if stripe_session_id.blank?

    session = Stripe::Checkout::Session.retrieve(
      id:     stripe_session_id,
      expand: ['payment_intent.latest_charge']
    )
    return :not_paid unless session.payment_status == 'paid'

    purchases = ticket_purchases.unpaid.includes(:ticket).to_a
    record_charge(session)

    unless paid_amount_matches?(session, purchases)
      update!(status: :failure)
      report_mismatch(session, purchases)
      return :mismatch
    end

    self.amount = session.amount_total
    update!(status: :success)
    purchases.each { |purchase| purchase.pay(self) }
    :fulfilled
  end

  # A user may have started an earlier checkout and never returned from it.
  # Complete it if it was actually paid; otherwise expire it so its tickets
  # can move to the new checkout.
  def settle_other_pending_checkouts
    pending = user.payments.unpaid.where(conference: conference).where.not(id: id).where.not(stripe_session_id: nil)
    pending.find_each do |payment|
      next unless payment.fulfill_checkout == :not_paid

      begin
        Stripe::Checkout::Session.expire(payment.stripe_session_id)
      rescue Stripe::InvalidRequestError
        # Already expired.
      end
      payment.update!(status: :failure)
    end
  end

  def record_charge(session)
    charge = session.payment_intent&.latest_charge
    self.last4 = charge&.payment_method_details&.card&.last4
    self.authorization_code = session.payment_intent&.id
  end

  def paid_amount_matches?(session, purchases)
    purchases.any? &&
      session.amount_total == amount &&
      session.currency.to_s.casecmp?(currency) &&
      line_items_total(build_line_items(purchases)) == amount
  end

  def report_mismatch(session, purchases)
    message = "Stripe payment #{id} (#{authorization_code}) was paid #{session.amount_total} " \
              "#{session.currency} but its #{purchases.size} linked ticket purchases no longer match " \
              "the expected #{amount} #{currency}. Tickets were not marked paid; reconcile by hand."
    Rails.logger.error(message)
    Sentry.capture_message(message, level: :error)
  end

  def line_items_total(line_items)
    line_items.sum { |item| item[:price_data][:unit_amount] * item[:quantity] }
  end

  def build_line_items(purchases)
    purchases.map do |tp|
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
