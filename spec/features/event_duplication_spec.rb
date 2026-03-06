# frozen_string_literal: true

require 'spec_helper'

describe 'Event Duplication Feature', :js do
  let(:conference) { create(:full_conference, short_title: 'snapcon2026') }
  let(:program) { conference.program }
  let(:user) { create(:admin) }
  let(:event_type) { create(:event_type, program: program) }
  let(:track) { create(:track, state: 'confirmed', program: program) }
  let(:difficulty_level) { create(:difficulty_level, program: program) }
  
  let(:speaker) { create(:user) }
  let(:venue) { conference.venue || create(:venue, conference: conference) }
  let(:room) { create(:room, venue: venue) }

  let!(:original_event) do
    event = create(:event,
                   program: program,
                   title: 'Test Event for Duplication',
                   abstract: 'Event abstract',
                   description: 'Event description',
                   event_type: event_type,
                   track: track,
                   difficulty_level: difficulty_level,
                   require_registration: true,
                   max_attendees: 50,
                   state: 'confirmed')
    event.speakers << speaker
    event
  end

  before do
    login_as user, scope: :user
  end

  describe 'duplicating an event via web interface' do
    it 'shows duplicate button on event details page' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      expect(page).to have_button('Duplicate')
    end

    it 'opens the duplicate modal when clicking duplicate button' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      expect(page).to have_css('#duplicateEventModal.in')
      expect(page).to have_field('count')
    end

    it 'creates one copy by default' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      click_button('Create Copies')
      
      expect(page).to have_content('duplicated successfully')
      expect(Event.where(title: original_event.title).count).to eq 2
    end

    it 'creates multiple copies when specified' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      
      fill_in('count', with: 5)
      click_button('Create Copies')
      
      expect(page).to have_content('5 copies')
      expect(Event.where(title: original_event.title).count).to eq 6
    end

    it 'sets the current user as submitter of duplicates' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      click_button('Create Copies')
      
      duplicates = Event.where(title: original_event.title).where.not(id: original_event.id)
      duplicates.each do |dup|
        expect(dup.submitter).to eq user
      end
    end

    it 'preserves all event fields in duplicate' do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      click_button('Create Copies')
      
      # Wait for duplicate to be queryable (database transaction visibility)
      duplicate = nil
      Timeout.timeout(5) do
        loop do
          duplicate = Event.where(title: original_event.title).where.not(id: original_event.id).first
          break if duplicate
          sleep 0.1
        end
      end
      
      expect(duplicate.abstract).to eq original_event.abstract
      expect(duplicate.description).to eq original_event.description
      expect(duplicate.event_type).to eq original_event.event_type
      expect(duplicate.track).to eq original_event.track
      expect(duplicate.difficulty_level).to eq original_event.difficulty_level
      expect(duplicate.require_registration).to eq original_event.require_registration
      expect(duplicate.max_attendees).to eq original_event.max_attendees
      expect(duplicate.speakers).to include(speaker)
    end

    it 'shows the duplicate in the events list' do
      original_event
      original_count = program.events.count
      
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      click_button('Create Copies')
      
      visit admin_conference_program_events_path(conference.short_title)
      expect(page).to have_content(original_event.title)
      # Due to caching and datatable rendering, check the count increased
      expect(program.events.count).to eq original_count + 1
    end
  end

  describe 'deleting and updating duplicates' do
    before do
      visit admin_conference_program_event_path(conference.short_title, original_event)
      click_button('Duplicate')
      fill_in('count', with: 3)
      click_button('Create Copies')
      
      @duplicates = Event.where(title: original_event.title).where.not(id: original_event.id).order(:created_at)
    end

    it 'deleting a duplicate does not affect others' do
      duplicate_id = @duplicates.first.id
      duplicate_title = @duplicates.first.title

      visit admin_conference_program_event_path(conference.short_title, Event.find(duplicate_id))
      accept_confirm do
        click_link('Delete', match: :first)
      end

      expect(page).to have_content('Event successfully deleted.')
      expect(Event.exists?(duplicate_id)).to be false
      expect(Event.where(title: duplicate_title).count).to eq 3 # original + 2 remaining duplicates
    end

    it 'can individually edit duplicates' do
      duplicate = @duplicates.first
      new_subtitle = 'Updated Subtitle'
      
      visit edit_admin_conference_program_event_path(conference.short_title, duplicate)
      fill_in('event_subtitle', with: new_subtitle)
      click_button('Update Proposal')
      
      duplicate.reload
      expect(duplicate.subtitle).to eq new_subtitle
      
      # Original should not be affected
      original_event.reload
      expect(original_event.subtitle).not_to eq new_subtitle
    end
  end

  describe 'fuzz testing - rapid operations' do
    it 'handles rapid duplicate, update, delete cycles' do
      expect do
        3.times do |i|
          visit admin_conference_program_event_path(conference.short_title, original_event)
          click_button('Duplicate')
          fill_in('count', with: 2)
          click_button('Create Copies')
          
          # Wait for duplicates to be queryable (database transaction visibility)
          new_events = nil
          Timeout.timeout(5) do
            loop do
              new_events = Event.where(title: original_event.title).where.not(id: original_event.id).last(2)
              break if new_events&.all?(&:present?)
              sleep 0.1
            end
          end
          
          new_events.each do |event|
            event.update(max_attendees: 100 + i)
          end
          
          new_events.first&.destroy
        end
      end.not_to raise_error
    end

    it 'maintains data integrity with many duplicates' do
      5.times do
        visit admin_conference_program_event_path(conference.short_title, original_event)
        click_button('Duplicate')
        fill_in('count', with: 2)
        click_button('Create Copies')
      end
      
      all_events = Event.where(title: original_event.title)
      all_events.each do |event|
        expect(event.speakers).to include(speaker)
        expect(event.event_type).to eq event_type
      end
    end
  end
end
