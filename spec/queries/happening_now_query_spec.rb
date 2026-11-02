# frozen_string_literal: true

require 'spec_helper'

describe HappeningNowQuery do
  include ActiveSupport::Testing::TimeHelpers

  # 12:00 in the conference's time zone (Pacific Daylight Time, UTC-7).
  let(:now) { Time.utc(2026, 6, 15, 19, 0) }
  let(:conference) do
    create(:conference, timezone: 'Pacific Time (US & Canada)', start_hour: 0, end_hour: 24,
                        start_date: Date.new(2026, 6, 14), end_date: Date.new(2026, 6, 17))
  end
  let(:program) { conference.program }
  let(:schedule) { create(:schedule, program: program) }
  let(:event_type) { create(:event_type, program: program, length: 30) }
  let(:query) { described_class.new(conference, now: now) }

  # start_time holds the conference's wall-clock time, so 12:00 local is
  # stored as 12:00 UTC.
  def schedule_at(local_time, schedule: self.schedule)
    event = create(:event, program: program, event_type: event_type, state: 'confirmed')
    create(:event_schedule, event: event, schedule: schedule, start_time: Time.utc(2026, 6, 15, *local_time))
  end

  before do
    travel_to(now)
    program.update!(selected_schedule: schedule)
  end

  describe '#happening_now' do
    it 'includes sessions in progress or starting within 15 minutes' do
      in_progress = schedule_at([11, 45]) # 11:45-12:15
      starting_soon = schedule_at([12, 15])

      expect(query.happening_now).to contain_exactly(in_progress, starting_soon)
    end

    it 'excludes sessions that ended, or start more than 15 minutes from now' do
      schedule_at([11, 0]) # 11:00-11:30
      schedule_at([12, 16])

      expect(query.happening_now).to be_empty
    end

    it 'matches EventSchedule#happening_now?' do
      schedules = [[11, 20], [11, 31], [11, 45], [12, 0], [12, 14], [12, 30]].map { |time| schedule_at(time) }

      expect(query.happening_now).to match_array(schedules.select(&:happening_now?))
    end

    it 'orders by start time' do
      later = schedule_at([12, 10])
      earlier = schedule_at([11, 50])

      expect(query.happening_now.to_a).to eq([earlier, later])
    end

    it 'ignores schedules other than the selected one' do
      schedule_at([12, 0], schedule: create(:schedule, program: program))

      expect(query.happening_now).to be_empty
    end

    it 'ignores other conferences' do
      other = create(:conference, timezone: 'Pacific Time (US & Canada)', start_hour: 0, end_hour: 24,
                                  start_date: Date.new(2026, 6, 14), end_date: Date.new(2026, 6, 17))
      other_schedule = create(:schedule, program: other.program)
      other.program.update!(selected_schedule: other_schedule)
      event = create(:event, program: other.program, state: 'confirmed')
      create(:event_schedule, event: event, schedule: other_schedule, start_time: Time.utc(2026, 6, 15, 12, 0))

      expect(query.happening_now).to be_empty
    end

    it "includes confirmed self-organized tracks' selected schedules" do
      track = create(:track, :self_organized, program: program, state: 'confirmed',
                                              start_date: Date.new(2026, 6, 15), end_date: Date.new(2026, 6, 15))
      track_schedule = create(:schedule, program: program, track: track)
      track.update!(selected_schedule: track_schedule)
      event = create(:event, program: program, event_type: event_type, track: track, state: 'confirmed')
      track_session = create(:event_schedule, event: event, schedule: track_schedule, room: track.room,
                                              start_time: Time.utc(2026, 6, 15, 12, 0))

      expect(query.happening_now).to contain_exactly(track_session)
    end

    it 'is empty when the program has no selected schedule' do
      schedule_at([12, 0])
      program.update!(selected_schedule: nil)

      expect(query.happening_now).to be_empty
    end
  end

  describe '#happening_next' do
    it 'returns every session at the next start time' do
      schedule_at([11, 0])
      first = schedule_at([13, 0])
      second = schedule_at([13, 0])
      schedule_at([14, 0])

      expect(query.happening_next).to contain_exactly(first, second)
    end

    it 'is empty when nothing is upcoming' do
      schedule_at([11, 0])

      expect(query.happening_next).to be_empty
    end
  end
end
