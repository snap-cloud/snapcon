# frozen_string_literal: true

require 'spec_helper'

describe Admin::EventsController do
  let(:conference) { create(:conference) }
  let!(:organizer) { create(:organizer, resource: conference) }
  # The where_object() and where_object_changes() methods of paper_trail gem are broken when having:
  # an Event with ID 1, an Event with ID 2, and a commercial with ID 1, for event with ID 2
  # (the numbers could be different as long as there is this matching of IDs).
  # We implemented or own where method to solve this and those ids are for testing this case.
  let!(:event_without_commercial) { create(:event, program: conference.program) }
  let!(:event_with_commercial) { create(:event, program: conference.program) }
  let!(:event_commercial) { create(:event_commercial, commercialable: event_with_commercial, url: 'https://www.youtube.com/watch?v=M9bq_alk-sw') }

  with_versioning do
    describe 'GET #show' do
      before do
        sign_in(organizer)
        get :show, params: { id: event_without_commercial.id, conference_id: conference.short_title }
      end

      # TODO-SNAPCON: This is a little sloppy. It should check for EventUser history...
      it 'assigns versions' do
        versions = event_without_commercial.versions.to_a
        expect(assigns(:versions)).to include(versions[0])
      end
    end
  end

  describe '#duplicate' do
    let(:dup_conference) { create(:conference, short_title: 'snapcon2026') }
    let(:program) { dup_conference.program }
    let(:user) { create(:admin) }
    let(:event_type) { create(:event_type, program: program) }
    let(:track) { create(:track, state: 'confirmed', program: program) }
    let(:difficulty_level) { create(:difficulty_level, program: program) }
    let(:speaker) { create(:user) }
    let(:volunteer) { create(:user) }

    let!(:original_event) do
      event = create(:event,
                     program:              program,
                     title:                'Original Event',
                     abstract:             'An abstract',
                     description:          'A description',
                     event_type:           event_type,
                     track:                track,
                     difficulty_level:     difficulty_level,
                     require_registration: true,
                     max_attendees:        50,
                     state:                'confirmed')
      event.speakers << speaker
      event.volunteers << volunteer
      event
    end

    before do
      sign_in user
    end

    context 'with single duplicate' do
      it 'creates one copy of the event' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         1
          }
        end.to change(Event, :count).by(1)
      end

      it 'redirects to the new event page' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        expect(response).to redirect_to(admin_conference_program_event_path(dup_conference.short_title, Event.last))
      end

      it 'sets a success flash message' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        expect(flash[:notice]).to include('duplicated successfully')
      end

      it 'assigns the current user as submitter' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        new_event = Event.last
        expect(new_event.submitter).to eq user
      end
    end

    context 'with multiple duplicates' do
      it 'creates the requested number of copies' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         3
          }
        end.to change(Event, :count).by(3)
      end

      it 'redirects to the events index when creating multiple' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         3
        }
        expect(response).to redirect_to(admin_conference_program_events_path(dup_conference.short_title))
      end

      it 'shows the count of created copies in flash message' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         3
        }
        expect(flash[:notice]).to include('3 copies')
      end
    end

    context 'with invalid count' do
      it 'shows error if count is 0' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         0
          }
        end.not_to change(Event, :count)

        expect(flash[:alert]).to include('Invalid number of duplicates')
      end

      it 'shows error if count is too high' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         200
          }
        end.not_to change(Event, :count)

        expect(flash[:alert]).to include('Invalid number of duplicates')
      end

      it 'shows error if count is negative' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         -5
          }
        end.not_to change(Event, :count)

        expect(flash[:alert]).to include('Invalid number of duplicates')
      end

      it 'accepts valid count at upper boundary (100)' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id,
            count:         100
          }
        end.to change(Event, :count).by(100)

        expect(flash[:notice]).to include('100 copies')
      end

      it 'shows error if count is missing' do
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id
          }
        end.not_to change(Event, :count)

        expect(flash[:alert]).to include('Invalid number of duplicates')
      end
    end

    context 'field copying' do
      let(:duplicate) do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        Event.last
      end

      it 'copies content fields' do
        expect(duplicate.title).to eq original_event.title
        expect(duplicate.abstract).to eq original_event.abstract
        expect(duplicate.description).to eq original_event.description
        expect(duplicate.subtitle).to eq original_event.subtitle
      end

      it 'copies configuration fields' do
        expect(duplicate.event_type).to eq original_event.event_type
        expect(duplicate.track).to eq original_event.track
        expect(duplicate.difficulty_level).to eq original_event.difficulty_level
        expect(duplicate.language).to eq original_event.language
      end

      it 'copies registration settings' do
        expect(duplicate.require_registration).to eq original_event.require_registration
        expect(duplicate.max_attendees).to eq original_event.max_attendees
      end

      it 'copies speakers and volunteers' do
        expect(duplicate.speakers).to include(speaker)
        expect(duplicate.volunteers).to include(volunteer)
      end

      it 'copies public status' do
        expect(duplicate.public).to eq original_event.public
      end

      it 'copies superevent status' do
        expect(duplicate.superevent).to eq original_event.superevent
      end

      it 'sets new event state' do
        expect(duplicate.state).to eq 'new'
      end

      it 'generates new guid' do
        expect(duplicate.guid).not_to eq original_event.guid
        expect(duplicate.guid).to be_present
      end

      it 'does not copy start_time' do
        expect(duplicate.start_time).to be_nil
      end

      it 'does not copy room' do
        expect(duplicate.room_id).to be_nil
      end

      it 'does not have parent' do
        expect(duplicate.parent_id).to be_nil
      end

      it 'does not copy registrations' do
        create(:registration)
        original_event.registrations << Registration.first
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        new_dup = Event.where(id: Event.last.id).first
        expect(new_dup.registrations).to be_empty
      end

      it 'does not copy votes' do
        create(:vote, event: original_event)
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        new_dup = Event.where(id: Event.last.id).first
        expect(new_dup.votes).to be_empty
      end

      it 'does not copy comments' do
        create(:comment, commentable: original_event)
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        new_dup = Event.where(id: Event.last.id).first
        expect(new_dup.comment_threads).to be_empty
      end
    end

    context 'duplicate of duplicate' do
      let(:first_duplicate) do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         1
        }
        Event.last
      end

      it 'can duplicate a duplicate' do
        # Evaluate first_duplicate before the expect block to avoid counting its creation
        dup_id = first_duplicate.id
        expect do
          post :duplicate, params: {
            conference_id: dup_conference.short_title,
            id:            dup_id,
            count:         1
          }
        end.to change(Event, :count).by(1)
      end

      it 'preserves all fields when duplicating a duplicate' do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            first_duplicate.id,
          count:         1
        }
        second_duplicate = Event.last

        expect(second_duplicate.title).to eq original_event.title
        expect(second_duplicate.speakers).to include(speaker)
        expect(second_duplicate.volunteers).to include(volunteer)
        expect(second_duplicate.difficulty_level).to eq original_event.difficulty_level
      end
    end

    context 'deletion independence' do
      let(:duplicates) do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         3
        }
        Event.where(title: original_event.title).order(:created_at).last(3)
      end

      it 'deleting a duplicate does not delete other duplicates' do
        dup_to_delete = duplicates.first
        second_dup_id = duplicates[1].id
        third_dup_id = duplicates[2].id

        expect do
          delete :destroy, params: {
            conference_id: dup_conference.short_title,
            id:            dup_to_delete.id
          }
        end.to change(Event, :count).by(-1)

        expect(Event.exists?(second_dup_id)).to be true
        expect(Event.exists?(third_dup_id)).to be true
      end

      it 'deleting the original does not delete duplicates' do
        dups_ids = duplicates.map(&:id)

        expect do
          delete :destroy, params: {
            conference_id: dup_conference.short_title,
            id:            original_event.id
          }
        end.to change(Event, :count).by(-1)

        dups_ids.each do |dup_id|
          expect(Event.exists?(dup_id)).to be true
        end
      end
    end

    context 'update independence' do
      let(:duplicates) do
        post :duplicate, params: {
          conference_id: dup_conference.short_title,
          id:            original_event.id,
          count:         2
        }
        Event.where(title: original_event.title).order(:created_at).last(2)
      end

      it 'updating original does not affect duplicates' do
        # Create duplicates first to capture original title
        dups = duplicates
        original_title = original_event.title
        new_title = 'Updated Original Title'
        original_event.update(title: new_title)

        dups.each do |dup|
          dup.reload
          expect(dup.title).not_to eq new_title
          expect(dup.title).to eq original_title
        end
      end

      it 'updating a duplicate does not affect original' do
        dup = duplicates.first
        new_title = 'Updated Duplicate Title'
        dup.update(title: new_title)

        original_event.reload
        expect(original_event.title).not_to eq new_title
      end

      it 'updating a duplicate does not affect other duplicates' do
        first_dup = duplicates.first
        second_dup = duplicates.last

        first_dup.update(max_attendees: 100)

        second_dup.reload
        expect(second_dup.max_attendees).to eq original_event.max_attendees
      end
    end
  end
end
