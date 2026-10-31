# frozen_string_literal: true

require 'spec_helper'

describe PaymentsController do
  let(:conference) { create(:conference) }
  let(:user) { create(:user) }

  before do
    create(:ticket, price: 10, price_currency: 'USD', conference: conference)
    sign_in user
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
