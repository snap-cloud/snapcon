# frozen_string_literal: true

require 'spec_helper'

describe RegistrationPeriod do
  # It is necessary to use bang version of let to build roles before user
  let!(:conference) { create(:conference) }
  let!(:organizer) { create(:organizer, email: 'admin@example.com', resource: conference) }
  let(:start_date) { Date.today }
  let(:end_date) { Date.today + 5 }

  context 'as organizer' do
    before do
      sign_in organizer
      visit admin_conference_registration_period_path(conference_id: conference)
      click_link 'New Registration Period'
    end

    context 'with tickets' do
      let!(:registration_ticket) do
        create(:registration_ticket, conference: conference)
      end

      it 'creates registration period', feature: true, js: true do
        fill_in 'registration_period_start_date', with: start_date.strftime('%Y/%m/%d')
        fill_in 'registration_period_end_date', with: end_date.strftime('%Y/%m/%d')
        click_button 'Save Registration Period'
        page.find('#flash')
        expect(flash).to eq('Registration Period successfully updated.')
        expect(page).to have_current_path(admin_conference_registration_period_path(conference.short_title),
                                          ignore_query: true)
        expect(page).to have_text("Ticket required?\nYes")
      end
    end

    context 'without tickets' do
      it 'creates registration period', feature: true, js: true do
        fill_in 'registration_period_start_date', with: start_date.strftime('%Y-%m-%d')
        fill_in 'registration_period_end_date', with: end_date.strftime('%Y-%m-%d')
        click_button 'Save Registration Period'
        page.find('#flash')
        expect(flash).to eq('Registration Period successfully updated.')
        expect(page).to have_current_path(admin_conference_registration_period_path(conference.short_title),
                                          ignore_query: true)
        expect(page).to have_text("Ticket required?\nNo")
      end
    end
  end
end
