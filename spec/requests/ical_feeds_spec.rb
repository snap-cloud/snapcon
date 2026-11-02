# frozen_string_literal: true

require 'spec_helper'

describe 'iCal feeds' do
  include Devise::Test::IntegrationHelpers

  def count_queries(&)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  # Passing difficulty_level stops the factory from creating an extra
  # conference for it, so the conference count stays fixed.
  def schedule_events(conference, count)
    create_list(:event_scheduled, count, program: conference.program, difficulty_level: nil)
  end

  # A self-organized track with its own selected schedule, so the feed has to
  # use the track's schedule (and room) for these events.
  def schedule_track_event(conference)
    program = conference.program
    room = create(:room, venue: conference.venue)
    track = create(:track, :self_organized, program: program, room: room, state: 'confirmed',
                   start_date: conference.start_date, end_date: conference.end_date)
    schedule = create(:schedule, program: program, track: track)
    track.update!(selected_schedule: schedule)
    # event_full assigns its own track in after(:build), so set ours afterwards.
    event = build(:event_full, program: program, state: 'confirmed')
    event.update!(track: track)
    create(:event_schedule, event: event, schedule: schedule, room: room,
           start_time: conference.start_date + 10.hours)
    event
  end

  let!(:conference) do
    create(:conference, splashpage: create(:splashpage, public: true), venue: create(:venue))
  end

  before do
    conference.program.update!(schedule_public: true)
  end

  # The ability file does not grant :calendar to guests or regular users, so
  # only admins can fetch /calendar.ics today.
  describe 'GET /calendar.ics?full=1' do
    before { sign_in create(:admin) }

    it 'lists every scheduled event with time, room, track and difficulty' do
      event = schedule_events(conference, 1).first
      track_event = schedule_track_event(conference)

      get '/calendar.ics', params: { full: 1 }

      expect(response).to have_http_status(:ok)
      calendar = Icalendar::Calendar.parse(response.body).first
      expect(calendar.events.map(&:uid)).to contain_exactly(event.guid, track_event.guid)

      vevent = calendar.events.find { |e| e.uid == event.guid }
      expect(vevent.dtstart.to_i).to eq(event.time.to_i)
      expect(vevent.location).to start_with("#{event.room.name} - ")
      expect(vevent.categories.flatten).to include(
        conference.title, "Difficulty: #{event.difficulty_level.title}", "Track: #{event.track.name}"
      )

      track_vevent = calendar.events.find { |e| e.uid == track_event.guid }
      expect(track_vevent.dtstart.to_i).to eq(track_event.time.to_i)
      expect(track_vevent.location).to start_with("#{track_event.track.room.name} - ")
    end

    it 'does not run more queries as the number of events grows' do
      schedule_events(conference, 2)
      small = count_queries { get '/calendar.ics', params: { full: 1 } }

      schedule_events(conference, 8)
      large = count_queries { get '/calendar.ics', params: { full: 1 } }

      expect(Icalendar::Calendar.parse(response.body).first.events.size).to eq(10)
      expect(large).to eq(small)
    end
  end

  describe 'GET /calendar.ics' do
    before { sign_in create(:admin) }

    it 'lists the conference' do
      get '/calendar.ics'

      calendar = Icalendar::Calendar.parse(response.body).first
      expect(calendar.events.map(&:uid)).to eq([conference.guid])
      expect(calendar.events.first.summary).to eq(conference.title)
    end
  end

  describe 'GET /conferences/:id/schedule.ics' do
    it 'does not run more queries as the number of events grows' do
      schedule_events(conference, 2)
      small = count_queries { get "/conferences/#{conference.short_title}/schedule.ics" }

      schedule_events(conference, 8)
      large = count_queries { get "/conferences/#{conference.short_title}/schedule.ics" }

      expect(Icalendar::Calendar.parse(response.body).first.events.size).to eq(10)
      expect(large).to eq(small)
    end
  end

  it 'returns event text as-is instead of evaluating it as a template' do
    schedule_events(conference, 1).first.update!(abstract: 'Abstract <%= 6 * 7 %>')

    get "/conferences/#{conference.short_title}/schedule.ics"

    expect(response.media_type).to eq('text/calendar')
    expect(Icalendar::Calendar.parse(response.body).first.events.first.description).to eq('Abstract <%= 6 * 7 %>')
  end

  describe 'caching' do
    around do |example|
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original_cache
    end

    def event_start(body, event)
      Icalendar::Calendar.parse(body).first.events.find { |e| e.uid == event.guid }.dtstart
    end

    context 'with /calendar.ics' do
      before { sign_in create(:admin) }

      it 'serves the cached feed until a session is rescheduled' do
        event = schedule_events(conference, 3).first
        first_queries = count_queries { get '/calendar.ics', params: { full: 1 } }
        first_body = response.body

        cached_queries = count_queries { get '/calendar.ics', params: { full: 1 } }
        expect(response.body).to eq(first_body)
        expect(cached_queries).to be < first_queries

        event.event_schedules.first.update!(start_time: conference.start_date + 15.hours)
        get '/calendar.ics', params: { full: 1 }
        expect(event_start(response.body, event).to_i).to eq((conference.start_date + 15.hours).to_i)
      end

      it 'refreshes when the venue changes' do
        get '/calendar.ics'
        conference.venue.update!(street: 'New Street 1')

        get '/calendar.ics'
        expect(Icalendar::Calendar.parse(response.body).first.events.first.location).to include('New Street 1')
      end

      it 'keeps the short and full feeds apart' do
        schedule_events(conference, 1)
        get '/calendar.ics'
        short_body = response.body

        get '/calendar.ics', params: { full: 1 }
        expect(response.body).not_to eq(short_body)
      end
    end

    context 'with /conferences/:id/schedule.ics' do
      it 'serves the cached feed until a session is rescheduled' do
        event = schedule_events(conference, 3).first
        path = "/conferences/#{conference.short_title}/schedule.ics"
        first_queries = count_queries { get path }
        first_body = response.body

        cached_queries = count_queries { get path }
        expect(response.body).to eq(first_body)
        expect(cached_queries).to be < first_queries

        event.event_schedules.first.update!(start_time: conference.start_date + 15.hours)
        get path
        expect(event_start(response.body, event).to_i).to eq((conference.start_date + 15.hours).to_i)
      end
    end
  end
end
