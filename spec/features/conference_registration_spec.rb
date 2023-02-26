# frozen_string_literal: true

require 'spec_helper'

describe Registration do
  let!(:conference) { create(:conference, registration_period: create(:registration_period, start_date: 3.days.ago)) }
  let!(:participant) { create(:user) }

  context 'as a participant' do
    before do
      sign_in participant
    end

    after do
      sign_out
    end

    context 'who is already registered' do
      let!(:registration) { create(:registration, user: participant, conference: conference) }

      it 'updates conference registration', feature: true, js: true do
        visit root_path
        click_link 'My Registration'
        expect(page).to have_current_path(conference_conference_registration_path(conference.short_title),
                                          ignore_query: true)

        click_link 'Edit your Registration'
        expect(page).to have_current_path(edit_conference_conference_registration_path(conference.short_title),
                                          ignore_query: true)

        click_button 'Update Registration'
        expect(conference.user_registered?(participant)).to be(true)
      end

      it 'unregisters for a conference', feature: true, js: true do
        visit root_path
        click_link 'My Registration'
        expect(page).to have_current_path(conference_conference_registration_path(conference.short_title),
                                          ignore_query: true)

        page.accept_alert do
          click_link 'Unregister'
        end
        page.find('#flash')
        expect(page).to have_content('not registered')
        expect(conference.user_registered?(participant)).to be(false)
      end
    end

    context 'who is not registered' do
      it 'registers for a conference', feature: true, js: true do
        visit root_path
        click_link 'Register'

        expect(page).to have_current_path(new_conference_conference_registration_path(conference.short_title),
                                          ignore_query: true)
        click_button 'Register'

        expect(conference.user_registered?(participant)).to be(true)
      end
    end
  end
end
