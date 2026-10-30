# frozen_string_literal: true

require 'spec_helper'

feature Conference do
  let(:user) { create(:admin) }

  describe 'admin' do
    let(:conference) { create(:conference) }

    scenario 'adds a new conference', feature: true, js: true do
      expected_count = Conference.count + 1
      sign_in user

      visit new_admin_conference_path

      fill_in 'conference_title', with: 'Example Con'
      fill_in 'conference_short_title', with: 'ExCon'

      select('(GMT+01:00) Berlin', from: 'conference[timezone]')

      today = Time.zone.today - 1
      fill_in 'conference_start_date', with: today.strftime('%Y/%m/%d')
      fill_in 'conference_end_date', with: (today + 7).strftime('%Y/%m/%d')
      click_button 'Create Conference'

      within('#flash') { expect(page).to have_text('Conference was successfully created.') }
      expect(Conference.count).to eq(expected_count)
      user.reload
      expect(user.has_cached_role?(:organizer, Conference.last)).to be(true)
    end

    it 'update conference', feature: true, js: true do
      conference = create(:conference)
      organizer = create(:organizer, resource: conference)

      expected_count = Conference.count

      sign_in organizer
      visit edit_admin_conference_path(conference.short_title)

      fill_in 'conference_title', with: 'New Con'
      fill_in 'conference_short_title', with: 'NewCon'

      day = Time.zone.today + 10
      fill_in 'conference_start_date', with: day.strftime('%Y/%m/%d')
      fill_in 'conference_end_date', with: (day + 7).strftime('%Y/%m/%d')
      page.accept_alert do
        click_button 'Update Conference'
      end

      within('#flash') { expect(page).to have_text('Conference was successfully updated.') }

      conference.reload
      expect(conference.title).to eq('New Con')
      expect(conference.short_title).to eq('NewCon')
      expect(Conference.count).to eq(expected_count)
    end
  end

  describe 'user views' do
    let!(:conference) { create(:full_conference, description: 'Welcome to this conference!', registered_attendees_message: 'This is an exclusive message!') }
    let!(:registered_user) { create(:user) }
    let!(:not_registered_user) { create(:user) }
    let!(:registration) { create(:registration, user: registered_user, conference: conference) }

    context 'when user is registered for conference' do
      before do
        sign_in registered_user
        visit conference_path(conference.short_title)
      end

      it 'shows registered attendees message and description' do
        expect(page).to have_content('Welcome to this conference!')
        expect(page).to have_content('This is an exclusive message!')
      end
    end

    context 'when user is not registered for conference' do
      before do
        sign_in not_registered_user
        visit conference_path(conference)
      end

      it 'shows conference description' do
        expect(page).to have_content('Welcome to this conference!')
      end

      it 'does not show registered attendees message' do
        expect(page).to have_no_content('This is an exclusive message!')
      end
    end
  end
end
