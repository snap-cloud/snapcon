# frozen_string_literal: true

require 'spec_helper'

describe SurveysController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  let!(:conference) do
    create(:conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, timezone: Time.current.zone)
  end
  let!(:survey_future) do
    create(:survey, surveyable: conference, start_date: Date.current + 2.days, end_date: Date.current + 3.days)
  end
  let!(:survey_past) do
    create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current - 1.day)
  end
  let!(:survey_present) do
    create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day)
  end

  describe 'GET #index' do
    context 'guest' do
      before do
        get :index, params: { conference_id: conference.short_title }
      end

      it '@sureveys variable is nil' do
        expect(assigns(:surveys)).to eq [survey_present]
      end
    end

    context 'signed in user' do
      before do
        sign_in user
        get :index, params: { conference_id: conference.short_title }
      end

      it 'assigns @surveys with active surveys' do
        expect(assigns(:surveys)).to eq [survey_present]
      end
    end
  end
end
