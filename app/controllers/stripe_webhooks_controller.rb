# frozen_string_literal: true

# Receives Stripe webhook events. Stripe signs every request, so this skips
# the session-based checks the rest of the app uses (login, CSRF, CanCan).
#
# The success page normally completes a checkout, but users can close the tab
# after paying. checkout.session.completed makes sure those payments still get
# their tickets. Payment#fulfill_checkout is idempotent, so it's fine for both
# paths to run.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  HANDLED_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze

  def create
    secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
    if secret.blank?
      Rails.logger.error('Stripe webhook received but STRIPE_WEBHOOK_SECRET is not set')
      head :service_unavailable
      return
    end

    begin
      event = Stripe::Webhook.construct_event(request.body.read, request.headers['Stripe-Signature'], secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      Rails.logger.warn("Rejected Stripe webhook: #{e.message}")
      head :bad_request
      return
    end

    handle_checkout_completed(event.data.object) if HANDLED_EVENTS.include?(event.type)
    head :ok
  end

  private

  def handle_checkout_completed(checkout_session)
    payment = Payment.find_by(stripe_session_id: checkout_session.id)
    if payment.nil?
      Rails.logger.warn("Stripe webhook for unknown Checkout session #{checkout_session.id}")
      return
    end

    result = payment.fulfill_checkout
    Rails.logger.info("Stripe webhook: payment #{payment.id} #{result}")
    # Ask Stripe to retry later if we couldn't reach its API.
    raise "Could not fulfill payment #{payment.id}" if result == :error
  end
end
