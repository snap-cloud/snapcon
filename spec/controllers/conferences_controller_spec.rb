# frozen_string_literal: true

require 'spec_helper'

describe ConferencesController do
  let(:conference) { create(:conference, splashpage: create(:splashpage, public: true), venue: create(:venue)) }
  let!(:cfp) { create(:cfp, program: conference.program) }
  let(:room) { create(:room, venue: conference.venue) }

  describe 'GET #index' do
    it 'Response code is 200' do
      get :index
      expect(response.response_code).to eq(200)
    end
  end

  describe 'GET #show' do
    context 'conference made public' do
      it 'assigns the requested conference to conference' do
        get :show, params: { id: conference.short_title }
        expect(assigns(:conference)).to eq conference
      end

      it 'renders the show template' do
        get :show, params: { id: conference.short_title }
        expect(response).to render_template :show
      end
    end

    context 'happening now' do
      render_views

      it 'does not query events when happening now is turned off' do
        conference.splashpage.update!(include_program: true, include_happening_now: false)
        expect(HappeningNowQuery).not_to receive(:new)

        get :show, params: { id: conference.short_title }
        expect(response.body).not_to include("id='happening-now'")
      end

      it 'queries events once when happening now is turned on' do
        conference.splashpage.update!(include_program: true, include_happening_now: true)
        expect(HappeningNowQuery).to receive(:new).once.and_call_original

        get :show, params: { id: conference.short_title }
        expect(response.body).to include("id='happening-now'")
      end
    end

    context 'accessing conference via custom domain' do
      before do
        conference.update_attribute(:custom_domain, 'lvh.me')
        @request.host = 'lvh.me'
      end

      it 'assigns correct conference' do
        get :show

        expect(response).to render_template :show
        expect(assigns(:conference)).to eq conference
      end
    end
  end

  describe 'OPTIONS #index' do
    it 'Response code is 200' do
      process :index
      expect(response.response_code).to eq(200)
    end
  end
end
