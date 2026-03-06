# frozen_string_literal: true

require 'spec_helper'

describe Admin::EventsController, type: :controller do
  let(:conference) { create(:conference, short_title: 'osem2023') }
  let(:program) { conference.program }
  let(:user) { create(:admin) }
  let(:event_type) { create(:event_type, program: program) }
  let(:track) { create(:track, state: 'confirmed', program: program) }
  let(:difficulty_level) { create(:difficulty_level, program: program) }
  
  let(:speaker) { create(:user) }
  let(:volunteer) { create(:user) }

  let(:original_event) do
    event = create(:event,
                   program: program,
                   title: 'Original Event',
                   abstract: 'An abstract',
                   description: 'A description',
                   event_type: event_type,
                   track: track,
                   difficulty_level: difficulty_level,
                   require_registration: true,
                   max_attendees: 50,
                   state: 'confirmed')
    event.speakers << speaker
    event.volunteers << volunteer
    event
  end

  before do
    sign_in user
  end

  describe '#duplicate' do
    context 'with single duplicate' do
      it 'creates one copy of the event' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: original_event.id,
            count: 1
          }
        end.to change(Event, :count).by(1)
      end

      it 'redirects to the new event page' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        expect(response).to redirect_to(admin_conference_program_event_path(conference.short_title, Event.last))
      end

      it 'sets a success flash message' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        expect(flash[:notice]).to include('duplicated successfully')
      end

      it 'assigns the current user as submitter' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        new_event = Event.last
        expect(new_event.submitter).to eq user
      end
    end

    context 'with multiple duplicates' do
      it 'creates the requested number of copies' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: original_event.id,
            count: 3
          }
        end.to change(Event, :count).by(3)
      end

      it 'redirects to the events index when creating multiple' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 3
        }
        expect(response).to redirect_to(admin_conference_program_events_path(conference.short_title))
      end

      it 'shows the count of created copies in flash message' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 3
        }
        expect(flash[:notice]).to include('3 copies')
      end
    end

    context 'with invalid count' do
      it 'defaults to 1 if count is 0' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: original_event.id,
            count: 0
          }
        end.to change(Event, :count).by(1)
      end

      it 'caps at 100 if count is too high' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: original_event.id,
            count: 200
          }
        end.to change(Event, :count).by(100)
      end

      it 'defaults to 1 if count is missing' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: original_event.id
          }
        end.to change(Event, :count).by(1)
      end
    end

    context 'field copying' do
      before do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        @duplicate = Event.last
      end

      it 'copies content fields' do
        expect(@duplicate.title).to eq original_event.title
        expect(@duplicate.abstract).to eq original_event.abstract
        expect(@duplicate.description).to eq original_event.description
        expect(@duplicate.subtitle).to eq original_event.subtitle
      end

      it 'copies configuration fields' do
        expect(@duplicate.event_type).to eq original_event.event_type
        expect(@duplicate.track).to eq original_event.track
        expect(@duplicate.difficulty_level).to eq original_event.difficulty_level
        expect(@duplicate.language).to eq original_event.language
      end

      it 'copies registration settings' do
        expect(@duplicate.require_registration).to eq original_event.require_registration
        expect(@duplicate.max_attendees).to eq original_event.max_attendees
      end

      it 'copies speakers and volunteers' do
        expect(@duplicate.speakers).to include(speaker)
        expect(@duplicate.volunteers).to include(volunteer)
      end

      it 'copies public status' do
        expect(@duplicate.public).to eq original_event.public
      end

      it 'sets new event state' do
        expect(@duplicate.state).to eq 'new'
      end

      it 'generates new guid' do
        expect(@duplicate.guid).not_to eq original_event.guid
        expect(@duplicate.guid).to be_present
      end

      it 'does not copy start_time' do
        expect(@duplicate.start_time).to be_nil
      end

      it 'does not copy room' do
        expect(@duplicate.room_id).to be_nil
      end

      it 'does not have parent' do
        expect(@duplicate.parent_id).to be_nil
      end

      it 'does not copy registrations' do
        create(:registration)
        original_event.registrations << Registration.first
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        new_duplicate = Event.where(id: Event.last.id).first
        expect(new_duplicate.registrations).to be_empty
      end

      it 'does not copy votes' do
        create(:vote, event: original_event)
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        new_duplicate = Event.where(id: Event.last.id).first
        expect(new_duplicate.votes).to be_empty
      end

      it 'does not copy comments' do
        create(:comment, commentable: original_event)
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        new_duplicate = Event.where(id: Event.last.id).first
        expect(new_duplicate.comment_threads).to be_empty
      end
    end

    context 'duplicate of duplicate' do
      before do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 1
        }
        @first_duplicate = Event.last
      end

      it 'can duplicate a duplicate' do
        expect do
          post :duplicate, params: {
            conference_id: conference.short_title,
            id: @first_duplicate.id,
            count: 1
          }
        end.to change(Event, :count).by(1)
      end

      it 'preserves all fields when duplicating a duplicate' do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: @first_duplicate.id,
          count: 1
        }
        second_duplicate = Event.last

        expect(second_duplicate.title).to eq original_event.title
        expect(second_duplicate.speakers).to include(speaker)
        expect(second_duplicate.volunteers).to include(volunteer)
        expect(second_duplicate.difficulty_level).to eq original_event.difficulty_level
      end
    end

    context 'deletion independence' do
      before do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 3
        }
        @duplicates = Event.where(title: original_event.title).order(:created_at).last(3)
      end

      it 'deleting a duplicate does not delete other duplicates' do
        duplicate_to_delete = @duplicates.first
        
        expect do
          delete :destroy, params: {
            conference_id: conference.short_title,
            id: duplicate_to_delete.id
          }
        end.to change(Event, :count).by(-1)
        
        expect(Event.exists?(@duplicates[1].id)).to be true
        expect(Event.exists?(@duplicates[2].id)).to be true
      end

      it 'deleting the original does not delete duplicates' do
        expect do
          delete :destroy, params: {
            conference_id: conference.short_title,
            id: original_event.id
          }
        end.to change(Event, :count).by(-1)
        
        @duplicates.each do |duplicate|
          expect(Event.exists?(duplicate.id)).to be true
        end
      end
    end

    context 'update independence' do
      before do
        post :duplicate, params: {
          conference_id: conference.short_title,
          id: original_event.id,
          count: 2
        }
        @duplicates = Event.where(title: original_event.title).order(:created_at).last(2)
      end

      it 'updating original does not affect duplicates' do
        new_title = 'Updated Original Title'
        original_event.update(title: new_title)
        
        @duplicates.each do |duplicate|
          duplicate.reload
          expect(duplicate.title).not_to eq new_title
          expect(duplicate.title).to eq original_event.title.sub(new_title, original_event.title)
        end
      end

      it 'updating a duplicate does not affect original' do
        duplicate = @duplicates.first
        new_title = 'Updated Duplicate Title'
        duplicate.update(title: new_title)
        
        original_event.reload
        expect(original_event.title).not_to eq new_title
      end

      it 'updating a duplicate does not affect other duplicates' do
        first_duplicate = @duplicates.first
        second_duplicate = @duplicates.last
        
        first_duplicate.update(max_attendees: 100)
        
        second_duplicate.reload
        expect(second_duplicate.max_attendees).to eq original_event.max_attendees
      end
    end
  end
end
