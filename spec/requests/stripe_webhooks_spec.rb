# frozen_string_literal: true

require 'spec_helper'

describe 'Stripe webhooks' do
  let(:secret) { 'whsec_test_secret' }
  let(:conference) { create(:conference) }
  let(:user) { create(:user) }
  let(:ticket) { create(:ticket, price: 10, price_currency: 'USD', conference: conference) }
  let!(:payment) do
    create(:payment, user: user, conference: conference, stripe_session_id: 'cs_test_webhook', amount: 1000)
  end
  let!(:purchase) do
    create(:ticket_purchase, ticket: ticket, user: user, conference: conference, quantity: 1, payment: payment)
  end
  let(:event_type) { 'checkout.session.completed' }
  let(:payload) do
    {
      id:     'evt_test',
      object: 'event',
      type:   event_type,
      data:   { object: { id: 'cs_test_webhook', object: 'checkout.session' } }
    }.to_json
  end
  let(:paid_session) do
    Stripe::Checkout::Session.construct_from(
      payment_status: 'paid', amount_total: 1000, currency: 'usd',
      payment_intent: { id: 'pi_test', latest_charge: nil }
    )
  end

  def signature_for(body, signing_secret = secret)
    timestamp = Time.current
    Stripe::Webhook::Signature.generate_header(
      timestamp, Stripe::Webhook::Signature.compute_signature(timestamp, body, signing_secret)
    )
  end

  def post_webhook(body, signature)
    post stripe_webhook_path, params: body, headers: { 'Stripe-Signature' => signature, 'CONTENT_TYPE' => 'application/json' }
  end

  around do |example|
    ClimateControl.modify(STRIPE_WEBHOOK_SECRET: secret) { example.run }
  end

  before { allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(paid_session) }

  it 'marks the linked tickets paid when a checkout completes' do
    post_webhook(payload, signature_for(payload))

    expect(response).to have_http_status(:ok)
    expect(payment.reload).to be_success
    expect(purchase.reload).to be_paid
  end

  it 'does nothing extra when the success page already completed the payment' do
    payment.fulfill_checkout

    expect { post_webhook(payload, signature_for(payload)) }.not_to(change { purchase.physical_tickets.count })
    expect(response).to have_http_status(:ok)
  end

  it 'rejects a request with an invalid signature' do
    post_webhook(payload, signature_for(payload, 'whsec_wrong'))

    expect(response).to have_http_status(:bad_request)
    expect(purchase.reload).not_to be_paid
  end

  it 'ignores a checkout session it does not know about' do
    other = payload.sub('cs_test_webhook', 'cs_test_unknown')
    post_webhook(other, signature_for(other))

    expect(response).to have_http_status(:ok)
  end

  context 'with an event type it does not handle' do
    let(:event_type) { 'checkout.session.expired' }

    it 'acknowledges it without changing the payment' do
      post_webhook(payload, signature_for(payload))

      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_unpaid
    end
  end

  context 'when STRIPE_WEBHOOK_SECRET is not set' do
    around do |example|
      ClimateControl.modify(STRIPE_WEBHOOK_SECRET: nil) { example.run }
    end

    it 'returns 503 so Stripe retries later' do
      post_webhook(payload, signature_for(payload))

      expect(response).to have_http_status(:service_unavailable)
      expect(purchase.reload).not_to be_paid
    end
  end
end
