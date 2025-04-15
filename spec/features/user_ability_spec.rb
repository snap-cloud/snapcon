# frozen_string_literal: true

require 'spec_helper'

feature 'Has correct abilities' do

  let(:conference) { create(:full_conference) } # user is cfp
  let(:user) { create(:user) }

  context 'when user has no role' do
    before do
      sign_in user
    end

    it 'for administration views' do
      visit admin_conference_path(conference.short_title)
      page.find('#flash')
      expect(page).to have_current_path root_path, ignore_query: true
      expect(flash).to eq 'You are not authorized to access this page.'
    end
  end
end
