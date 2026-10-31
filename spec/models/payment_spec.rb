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
require 'spec_helper'

describe Payment do
  context 'new payment' do
    let(:payment) { create(:payment) }

    it 'sets status to "unpaid" by default' do
      expect(payment.status).to eq('unpaid')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:conference_id) }
    it { is_expected.to validate_presence_of(:currency) }
  end

  describe '#amount_to_pay' do
    let!(:user) { create(:user) }
    let!(:conference) { create(:conference) }
    let(:ticket_1) { create(:ticket, price: 10, price_currency: 'USD', conference: conference) }
    let(:payment) { create(:payment, user: user, conference: conference) }

    it 'returns correct unpaid amount' do
      create(:ticket_purchase, ticket: ticket_1, user: user, quantity: 8)
      expect(payment.amount_to_pay).to eq(8000)
    end
  end

  describe '#create_checkout_session' do
    let!(:user) { create(:user) }
    let!(:conference) { create(:conference) }
    let!(:ticket_1) { create(:ticket, price: 10, price_currency: 'USD', conference: conference) }
    let!(:tickets) { { ticket_1.id.to_s => '2' } }
    let(:payment) { create(:payment, user: user, conference: conference) }

    before { TicketPurchase.purchase(conference, user, tickets, ticket_1.price_currency) }

    context 'when the session is created successfully' do
      let(:mock_session) do
        double('Stripe::Checkout::Session',
               id:  'cs_test_session_123',
               url: 'https://checkout.stripe.com/pay/cs_test_session_123')
      end

      it 'creates a Stripe Checkout Session with line items' do
        create_args = nil
        allow(Stripe::Checkout::Session).to receive(:create) do |**args|
          create_args = args
          mock_session
        end

        result = payment.create_checkout_session(
          success_url: 'https://example.com/success?session_id={CHECKOUT_SESSION_ID}',
          cancel_url:  'https://example.com/cancel'
        )

        expect(result).to eq(mock_session)
        expect(create_args).to include(
          payment_method_types: ['card'],
          mode:                 'payment',
          customer_email:       user.email
        )
        expect(create_args[:line_items]).to contain_exactly(
          hash_including(
            price_data: hash_including(
              currency:     'usd',
              product_data: hash_including(name: ticket_1.title),
              unit_amount:  1000
            ),
            quantity:   2
          )
        )
      end

      it 'stores the session id on the payment' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(mock_session)

        payment.create_checkout_session(
          success_url: 'https://example.com/success',
          cancel_url:  'https://example.com/cancel'
        )

        payment.reload
        expect(payment.stripe_session_id).to eq('cs_test_session_123')
      end

      it 'stores the expected amount in cents' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(mock_session)

        payment.create_checkout_session(success_url: 'https://example.com/success', cancel_url: 'https://example.com/cancel')

        expect(payment.reload.amount).to eq(2000)
      end

      it 'links the unpaid ticket purchases to the payment' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(mock_session)

        payment.create_checkout_session(success_url: 'https://example.com/success', cancel_url: 'https://example.com/cancel')

        expect(user.ticket_purchases.unpaid.pluck(:payment_id)).to all(eq(payment.id))
      end
    end

    context 'when an earlier checkout was never completed' do
      let!(:earlier_payment) do
        create(:payment, user: user, conference: conference, stripe_session_id: 'cs_test_earlier')
      end
      let(:new_session) { double('Stripe::Checkout::Session', id: 'cs_test_new', url: 'https://checkout.stripe.com/x') }

      before do
        user.ticket_purchases.update_all(payment_id: earlier_payment.id)
        allow(Stripe::Checkout::Session).to receive(:create).and_return(new_session)
        allow(Stripe::Checkout::Session).to receive(:expire)
      end

      it 'expires the unpaid earlier session and moves the tickets to the new payment' do
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_return(double('Stripe::Checkout::Session', payment_status: 'unpaid'))
        expect(Stripe::Checkout::Session).to receive(:expire).with('cs_test_earlier')

        payment.create_checkout_session(success_url: 'https://example.com/success', cancel_url: 'https://example.com/cancel')

        expect(earlier_payment.reload).to be_failure
        expect(user.ticket_purchases.pluck(:payment_id)).to all(eq(payment.id))
      end

      it 'completes the earlier session instead if it was paid' do
        earlier_payment.update!(amount: 2000)
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_return(double('Stripe::Checkout::Session',
                             payment_status: 'paid', amount_total: 2000, currency: 'usd',
                             payment_intent: double(id: 'pi_earlier', latest_charge: nil)))
        expect(Stripe::Checkout::Session).not_to receive(:create)

        result = payment.create_checkout_session(success_url: 'https://example.com/success',
                                                 cancel_url:  'https://example.com/cancel')

        expect(earlier_payment.reload).to be_success
        expect(user.ticket_purchases.unpaid).to be_empty
        expect(result).to be_nil
      end
    end

    context 'when Stripe raises an error' do
      before do
        allow(Stripe::Checkout::Session).to receive(:create)
          .and_raise(Stripe::StripeError.new('Test error'))
      end

      it 'returns nil' do
        result = payment.create_checkout_session(
          success_url: 'https://example.com/success',
          cancel_url:  'https://example.com/cancel'
        )

        expect(result).to be_nil
      end

      it 'sets status to failure' do
        payment.create_checkout_session(
          success_url: 'https://example.com/success',
          cancel_url:  'https://example.com/cancel'
        )

        expect(payment.status).to eq('failure')
      end

      it 'adds error message' do
        payment.create_checkout_session(
          success_url: 'https://example.com/success',
          cancel_url:  'https://example.com/cancel'
        )

        expect(payment.errors[:base]).to include('Test error')
      end
    end
  end

  describe '#fulfill_checkout' do
    let!(:user) { create(:user) }
    let!(:conference) { create(:conference) }
    let!(:ticket) { create(:ticket, price: 10, price_currency: 'USD', conference: conference) }
    let(:payment) do
      create(:payment, user: user, conference: conference, stripe_session_id: 'cs_test_123', amount: 2000)
    end
    let!(:purchase) do
      create(:ticket_purchase, ticket: ticket, user: user, conference: conference, quantity: 2, payment: payment)
    end
    let(:mock_charge) { double('Stripe::Charge', payment_method_details: double(card: double(last4: '4242'))) }
    let(:payment_status) { 'paid' }
    let(:amount_total) { 2000 }
    let(:mock_session) do
      double('Stripe::Checkout::Session',
             payment_status: payment_status,
             amount_total:   amount_total,
             currency:       'usd',
             payment_intent: double(id: 'pi_test_123', latest_charge: mock_charge))
    end

    before do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(mock_session)
    end

    context 'when the payment was successful' do
      it 'returns :fulfilled' do
        expect(payment.fulfill_checkout).to eq(:fulfilled)
      end

      it 'records the charge on the payment' do
        payment.fulfill_checkout
        payment.reload
        expect(payment).to be_success
        expect(payment.amount).to eq(2000)
        expect(payment.last4).to eq('4242')
        expect(payment.authorization_code).to eq('pi_test_123')
      end

      it 'marks the linked ticket purchase paid and issues physical tickets' do
        payment.fulfill_checkout
        expect(purchase.reload).to be_paid
        expect(purchase.physical_tickets.count).to eq(2)
      end

      it 'does not mark unlinked ticket purchases paid' do
        other_ticket = create(:ticket, price: 5, price_currency: 'USD', conference: conference)
        added_later = create(:ticket_purchase, ticket: other_ticket, user: user, conference: conference, quantity: 1)

        payment.fulfill_checkout

        expect(added_later.reload).not_to be_paid
      end
    end

    context 'when called again after it was fulfilled' do
      before { payment.fulfill_checkout }

      it 'returns :already_fulfilled without asking Stripe again' do
        expect(Stripe::Checkout::Session).not_to receive(:retrieve)
        expect(payment.fulfill_checkout).to eq(:already_fulfilled)
      end

      it 'does not issue more physical tickets' do
        expect { payment.fulfill_checkout }.not_to(change { purchase.physical_tickets.count })
      end
    end

    context 'when a linked ticket quantity changed after checkout started' do
      before { purchase.update!(quantity: 10) }

      it 'returns :mismatch and does not mark the tickets paid' do
        expect(payment.fulfill_checkout).to eq(:mismatch)
        expect(purchase.reload).not_to be_paid
        expect(payment.reload).to be_failure
      end

      it 'records the charge so it can be refunded or reconciled' do
        payment.fulfill_checkout
        expect(payment.reload.authorization_code).to eq('pi_test_123')
      end
    end

    context 'when Stripe charged a different amount' do
      let(:amount_total) { 100 }

      it 'returns :mismatch' do
        expect(payment.fulfill_checkout).to eq(:mismatch)
        expect(purchase.reload).not_to be_paid
      end
    end

    context 'when the session has not been paid' do
      let(:payment_status) { 'unpaid' }

      it 'returns :not_paid and leaves the payment unpaid' do
        expect(payment.fulfill_checkout).to eq(:not_paid)
        expect(payment.reload).to be_unpaid
        expect(purchase.reload).not_to be_paid
      end
    end

    [
      Stripe::APIConnectionError.new('Connection failed'),
      Stripe::AuthenticationError.new('Invalid API key'),
      Stripe::InvalidRequestError.new('Invalid session', {}),
      Stripe::RateLimitError.new('Rate limit exceeded')
    ].each do |error|
      context "when Stripe raises #{error.class.name}" do
        before { allow(Stripe::Checkout::Session).to receive(:retrieve).and_raise(error) }

        it 'returns :error without raising' do
          expect(payment.fulfill_checkout).to eq(:error)
          expect(payment.reload).to be_unpaid
        end
      end
    end
  end
end
