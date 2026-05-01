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

  describe '#complete_checkout' do
    let!(:user) { create(:user) }
    let!(:conference) { create(:conference) }
    let(:payment) { create(:payment, user: user, conference: conference, stripe_session_id: 'cs_test_123') }

    context 'when the payment was successful' do
      let(:mock_charge) do
        double('Stripe::Charge',
               payment_method_details: double(card: double(last4: '4242')))
      end

      let(:mock_session) do
        double('Stripe::Checkout::Session',
               payment_status: 'paid',
               amount_total:   2000,
               payment_intent: double(id: 'pi_test_123', latest_charge: mock_charge))
      end

      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(mock_session)
      end

      it 'sets status to success' do
        payment.complete_checkout
        expect(payment.status).to eq('success')
      end

      it 'assigns amount' do
        payment.complete_checkout
        expect(payment.amount).to eq(2000)
      end

      it 'assigns last4' do
        payment.complete_checkout
        expect(payment.last4).to eq('4242')
      end

      it 'assigns authorization_code from payment intent' do
        payment.complete_checkout
        expect(payment.authorization_code).to eq('pi_test_123')
      end
    end

    context 'when the payment was not successful' do
      let(:mock_session) do
        double('Stripe::Checkout::Session',
               payment_status: 'unpaid',
               payment_intent: nil)
      end

      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(mock_session)
      end

      it 'sets status to failure' do
        payment.complete_checkout
        expect(payment.status).to eq('failure')
      end

      it 'returns false' do
        expect(payment.complete_checkout).to be false
      end
    end

    context 'when Stripe raises an error' do
      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_raise(Stripe::APIConnectionError.new('Connection failed'))
      end

      it 'does not raise' do
        expect { payment.complete_checkout }.not_to raise_error
      end

      it 'sets status to failure' do
        payment.complete_checkout
        expect(payment.status).to eq('failure')
      end

      it 'returns false' do
        expect(payment.complete_checkout).to be false
      end
    end

    context 'when there is an authentication error' do
      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_raise(Stripe::AuthenticationError.new('Invalid API key'))
      end

      it 'does not raise' do
        expect { payment.complete_checkout }.not_to raise_error
      end
    end

    context 'when there is an invalid request' do
      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Invalid session', {}))
      end

      it 'does not raise' do
        expect { payment.complete_checkout }.not_to raise_error
      end
    end

    context 'when Stripe rate limit exceeds' do
      before do
        allow(Stripe::Checkout::Session).to receive(:retrieve)
          .and_raise(Stripe::RateLimitError.new('Rate limit exceeded'))
      end

      it 'does not raise' do
        expect { payment.complete_checkout }.not_to raise_error
      end
    end
  end
end
