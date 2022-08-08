# frozen_string_literal: true

require 'spec_helper'

describe Ticket do
  let!(:conference) { create(:conference, title: 'ExampleCon') }
  let!(:organizer) { create(:organizer, resource: conference) }

  context 'as a organizer' do
    before do
      sign_in organizer
    end

    after do
      sign_out
    end

    it 'add a valid ticket', feature: true do
      visit admin_conference_tickets_path(conference.short_title)
      click_link 'Add Ticket'

      fill_in 'ticket_title', with: 'Business Ticket'
      fill_in 'ticket_description', with: 'The business ticket'
      fill_in 'ticket_price', with: '100'

      click_button 'Create Ticket'
      page.find('#flash')
      expect(flash).to eq('Ticket successfully created.')
      expect(Ticket.count).to eq(2)
    end

    it 'add a invalid ticket', feature: true do
      visit admin_conference_tickets_path(conference.short_title)
      click_link 'Add Ticket'

      fill_in 'ticket_title', with: ''
      fill_in 'ticket_price', with: '-1'

      click_button 'Create Ticket'
      page.find('#flash')
      expect(flash).to eq("Creating Ticket failed: Title can't be blank. Price cents must be greater than or equal to 0.")
      expect(Ticket.count).to eq(1)
    end

    it 'add a hidden ticket', feature: true do
      visit admin_conference_tickets_path(conference.short_title)
      click_link 'Add Ticket'

      fill_in 'ticket_title', with: 'Hidden Ticket'
      fill_in 'ticket_description', with: 'The hidden ticket'
      fill_in 'ticket_price', with: '100'
      uncheck 'ticket_visible'

      click_button 'Create Ticket'
      page.find('#flash')
      expect(flash).to eq('Ticket successfully created.')
      expect(Ticket.count).to eq(2)
      expect(Ticket.visible.count).to eq(1)
    end

    context 'Ticket already created' do
      let!(:ticket) { create(:ticket, title: 'Business Ticket', price: 100, conference_id: conference.id) }

      it 'edit valid ticket', feature: true do
        visit admin_conference_tickets_path(conference.short_title)
        click_link('Edit', href: edit_admin_conference_ticket_path(conference.short_title, ticket.id))

        fill_in 'ticket_title', with: 'Event Ticket'
        fill_in 'ticket_price', with: '50'

        click_button 'Update Ticket'

        ticket.reload
        # It's necessary to multiply by 100 because the price is in cents
        page.find('#flash')
        expect(flash).to eq('Ticket successfully updated.')
        expect(ticket.price).to eq(Money.new(50 * 100, 'USD'))
        expect(ticket.title).to eq('Event Ticket')
        expect(Ticket.count).to eq(2)
      end

      it 'edit invalid ticket', feature: true do
        visit admin_conference_tickets_path(conference.short_title)
        click_link('Edit', href: edit_admin_conference_ticket_path(conference.short_title, ticket.id))

        fill_in 'ticket_title', with: ''
        fill_in 'ticket_price', with: '-5'

        click_button 'Update Ticket'

        ticket.reload
        # It's necessary to multiply by 100 because the price is in cents
        page.find('#flash')
        expect(ticket.price).to eq(Money.new(100 * 100, 'USD'))
        expect(ticket.title).to eq('Business Ticket')
        expect(flash).to eq("Ticket update failed: Title can't be blank. Price cents must be greater than or equal to 0.")
        expect(Ticket.count).to eq(2)
      end

      it 'delete ticket', feature: true, js: true do
        visit admin_conference_tickets_path(conference.short_title)
        click_link('Delete', href: admin_conference_ticket_path(conference.short_title, ticket.id))
        page.accept_alert
        page.find('#flash')
        expect(flash).to eq('Ticket successfully deleted.')
        expect(Ticket.count).to eq(1)
      end
    end
  end
end
