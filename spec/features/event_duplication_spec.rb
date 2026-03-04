# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                           :bigint           not null, primary key
#  abstract                     :text
#  comments_count               :integer          default(0), not null
#  committee_review             :text
#  description                  :text
#  guid                         :string           not null
#  is_highlight                 :boolean          default(FALSE)
#  language                     :string
#  max_attendees                :integer
#  presentation_mode            :integer
#  progress                     :string           default("new"), not null
#  proposal_additional_speakers :text
#  public                       :boolean          default(TRUE)
#  require_registration         :boolean
#  start_time                   :datetime
#  state                        :string           default("new"), not null
#  submission_text              :text
#  subtitle                     :string
#  superevent                   :boolean
#  title                        :string           not null
#  week                         :integer
#  created_at                   :datetime
#  updated_at                   :datetime
#  difficulty_level_id          :integer
#  event_type_id                :integer
#  parent_id                    :integer
#  program_id                   :integer
#  room_id                      :integer
#  track_id                     :integer
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => events.id)
#
require 'spec_helper'

describe EventDuplicator do
  let(:conference) { create(:conference) }
  let(:track) { create(:track, state: 'confirmed', program: conference.program) }
  let(:event_type) { create(:event_type, program: conference.program) }

  let(:original_event) do
    create(:event,
           program:              conference.program,
           title:                'Coffee Break',
           abstract:             'A short break for coffee',
           description:          'Attendees are encouraged to mingle',
           event_type:           event_type,
           track:                track,
           require_registration: false,
           max_attendees:        20,
           state:                'confirmed',
           start_time:           Time.current)
  end

  before do
    create(:vote, event: original_event, user: create(:user))
    create(:comment, commentable: original_event)
    original_event.registrations << create(:registration)
  end

  subject(:duplicator) { described_class.new(original_event) }

  describe '#duplicate' do
    subject(:duplicate) { duplicator.duplicate }

    it 'returns a new, persisted Event' do
      expect(duplicate).to be_a(Event)
      expect(duplicate).to be_persisted
    end

    it 'creates a distinct record with new id' do
      expect(duplicate.id).not_to eq original_event.id
    end

    describe 'copied fields' do
      it 'copies the title' do
        expect(duplicate.title).to eq original_event.title
      end

      it 'copies the abstract' do
        expect(duplicate.abstract).to eq original_event.abstract
      end

      it 'copies the description' do
        expect(duplicate.description).to eq original_event.description
      end

      it 'copies the event_type' do
        expect(duplicate.event_type).to eq original_event.event_type
      end

      it 'copies the track' do
        expect(duplicate.track).to eq original_event.track
      end

      it 'copies require_registration' do
        expect(duplicate.require_registration).to eq original_event.require_registration
      end

      it 'copies max_attendees' do
        expect(duplicate.max_attendees).to eq original_event.max_attendees
      end
    end

    describe 'reset fields' do
      before do
        venue = create(:venue, conference: conference)
        room = create(:room, venue: venue)
        create(:event_schedule, event: original_event, room: room)
      end

      it 'does not copy start_time' do
        expect(duplicate.start_time).to be_nil
      end

      it 'resets state to "new"' do
        expect(duplicate.state).to eq 'new'
      end

      it 'has no room assigned' do
        expect(duplicate.room_id).to be_nil
      end

      it 'has no parent assigned' do
        child_event = create(:event, program: conference.program, parent_id: original_event.id)
        duplicate_child = described_class.new(child_event).duplicate
        expect(duplicate_child.parent_id).to be_nil
      end

      it 'generates a new unique guid' do
        expect(duplicate.guid).not_to eq original_event.guid
        expect(duplicate.guid).to be_present
      end
    end

    describe 'excluded attendee data' do
      it 'has no registrations' do
        expect(duplicate.registrations).to be_empty
      end

      it 'has no votes' do
        expect(duplicate.votes).to be_empty
      end

      it 'has no comments' do
        expect(duplicate.comment_threads).to be_empty
      end
    end

    describe 'belongs to the same program' do
      it 'is scoped to the same conference program' do
        expect(duplicate.program).to eq original_event.program
      end
    end
  end
end

require 'spec_helper'

describe 'Scheduling a duplicated event' do
  let(:conference) do
    create(:conference,
           start_date: Date.today,
           end_date:   Date.today + 2,
           start_hour: 9,
           end_hour:   20)
  end
  let(:schedule)  { create(:schedule, program: conference.program) }
  let(:venue)     { conference.venue || create(:venue, conference: conference) }
  let(:room)      { create(:room, venue: venue) }

  let(:original_start_time) { Time.current.change(hour: 10, min: 0) }
  let(:duplicate_start_time) { Time.current.change(hour: 14, min: 0) }

  let(:original_event) do
    create(:event, state: 'confirmed', program: conference.program)
  end

  let(:duplicate_event) do
    EventDuplicator.new(original_event).duplicate
  end

  let!(:original_schedule) do
    create(:event_schedule,
           event:      original_event,
           schedule:   schedule,
           room:       room,
           start_time: original_start_time)
  end

  describe 'the duplicate event' do
    it 'starts with no event_schedules' do
      expect(duplicate_event.event_schedules).to be_empty
    end

    it 'is not scheduled before a time is assigned' do
      expect(duplicate_event.scheduled?).to be false
    end

    context 'after being given a new start_time via EventSchedule' do
      let!(:duplicate_schedule) do
        create(:event_schedule,
               event:      duplicate_event,
               schedule:   schedule,
               room:       room,
               start_time: duplicate_start_time)
      end

      it 'is scheduled' do
        expect(duplicate_event.scheduled?).to be true
      end

      it 'has a different start_time than the original' do
        expect(duplicate_schedule.start_time).not_to eq original_schedule.start_time
      end

      it 'has the correct start_time' do
        expect(duplicate_schedule.start_time).to eq duplicate_start_time
      end

      it 'is a valid event_schedule' do
        expect(duplicate_schedule).to be_valid
      end
    end
  end

  describe 'the original event' do
    before do
      create(:event_schedule,
             event:      duplicate_event,
             schedule:   schedule,
             room:       room,
             start_time: duplicate_start_time)
    end

    it 'remains scheduled' do
      expect(original_event.scheduled?).to be true
    end

    it 'retains its original start_time' do
      expect(original_schedule.start_time).to eq original_start_time
    end

    it 'still has exactly one event_schedule' do
      expect(original_event.event_schedules.count).to eq 1
    end
  end

  describe 'both events scheduled independently' do
    let!(:duplicate_schedule) do
      create(:event_schedule,
             event:      duplicate_event,
             schedule:   schedule,
             room:       room,
             start_time: duplicate_start_time)
    end

    it 'both are scheduled' do
      expect(original_event.scheduled?).to be true
      expect(duplicate_event.scheduled?).to be true
    end

    it 'do not share the same start_time' do
      expect(original_schedule.start_time).not_to eq duplicate_schedule.start_time
    end

    it 'each has exactly one event_schedule' do
      expect(original_event.event_schedules.count).to eq 1
      expect(duplicate_event.event_schedules.count).to eq 1
    end

    it 'neither event_schedule is the same record' do
      expect(original_schedule.id).not_to eq duplicate_schedule.id
    end
  end
end