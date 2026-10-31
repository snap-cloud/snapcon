# frozen_string_literal: true

require 'spec_helper'

describe PaymentsController do
  let(:conference) { create(:conference) }
  let(:user) { create(:user) }
  let!(:ticket) { create(:ticket, price: 10, price_currency: 'USD', conference: conference) }

  before { sign_in user }

  describe 'POST #create' do
    let!(:purchase) { create(:ticket_purchase, ticket: ticket, user: user, conference: conference, quantity: 1) }

    before do
      allow(Stripe::Checkout::Session).to receive(:create)
        .and_return(Stripe::Checkout::Session.construct_from(id: 'cs_test_new', url: checkout_url))
    end

    context 'when Stripe returns its hosted checkout page' do
      let(:checkout_url) { 'https://checkout.stripe.com/c/pay/cs_test_new' }

      it 'redirects to Stripe' do
        post :create, params: { conference_id: conference.short_title }
        expect(response).to redirect_to checkout_url
      end
    end

    context 'when the checkout URL is not on Stripe' do
      let(:checkout_url) { 'https://evil.example.com/pay' }

      it 'does not redirect off-site' do
        post :create, params: { conference_id: conference.short_title }
        expect(response).to redirect_to new_conference_payment_path(conference.short_title)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'GET #success' do
    context 'when the checkout session belongs to another user' do
      let!(:other_payment) do
        create(:payment, user: create(:user), conference: conference, stripe_session_id: 'cs_test_other')
      end

      it 'does not look up the session with Stripe' do
        expect(Stripe::Checkout::Session).not_to receive(:retrieve)
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_other' }
      end

      it 'redirects back to the payment page' do
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_other' }
        expect(response).to redirect_to new_conference_payment_path(conference.short_title)
        expect(flash[:error]).to eq('Payment not found. Please try again.')
      end

      it 'leaves the other payment unpaid' do
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_other' }
        expect(other_payment.reload).to be_unpaid
      end
    end

    context 'when the checkout session belongs to the current user' do
      let(:payment) do
        create(:payment, user: user, conference: conference, stripe_session_id: 'cs_test_mine', amount: 1000)
      end
      let!(:purchase) do
        create(:ticket_purchase, ticket: ticket, user: user, conference: conference, quantity: 1, payment: payment)
      end
      let(:paid_session) do
        Stripe::Checkout::Session.construct_from(
          payment_status: 'paid', amount_total: 1000, currency: 'usd',
          payment_intent: { id: 'pi_test', latest_charge: nil }
        )
      end

      before { allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(paid_session) }

      it 'marks the purchase paid and shows the tickets' do
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_mine' }

        expect(purchase.reload).to be_paid
        expect(response).to redirect_to conference_physical_tickets_path(conference.short_title)
      end

      it 'does not pay for tickets added after checkout when the success page is revisited' do
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_mine' }
        added_later = create(:ticket_purchase, ticket: create(:ticket, price: 50, conference: conference),
                                               user: user, conference: conference, quantity: 3)

        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_mine' }

        expect(added_later.reload).not_to be_paid
        expect(response).to redirect_to conference_physical_tickets_path(conference.short_title)
      end

      it 'tells the user to contact the organizers when the order changed during checkout' do
        purchase.update!(quantity: 5)

        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_mine' }

        expect(purchase.reload).not_to be_paid
        expect(response).to redirect_to conference_tickets_path(conference.short_title)
        expect(flash[:error]).to include('contact the organizers')
      end
    end

    context 'when the checkout session belongs to another conference' do
      before do
        create(:payment, user: user, conference: create(:conference), stripe_session_id: 'cs_test_elsewhere')
      end

      it 'does not look up the session with Stripe' do
        expect(Stripe::Checkout::Session).not_to receive(:retrieve)
        get :success, params: { conference_id: conference.short_title, session_id: 'cs_test_elsewhere' }
      end
    end
  end
end
