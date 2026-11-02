# frozen_string_literal: true

module ConferenceHelper
  # Return true if only call_for_papers or call_for_tracks or call_for_booths is open
  def one_call_open(*calls)
    calls.one? { |call| call.try(:open?) }
  end
  # Return true if exactly two of those calls are open: call_for_papers , call_for_tracks , call_for_booths

  def two_calls_open(*calls)
    calls.count { |call| call.try(:open?) } == 2
  end

  # URL for sponsorship emails
  def sponsorship_mailto(conference)
    [
      'mailto:',
      conference.contact.sponsor_email,
      '?subject=',
      url_encode(conference.short_title),
      '%20Sponsorship'
    ].join
  end

  def short_ticket_description(ticket)
    return unless ticket.description

    markdown(ticket.description.split("\n").first&.strip)
  end

  def conference_color(conference)
    conference.color.presence || Rails.configuration.conference[:default_color]
  end

  # Everything icalendar_proposals reads from each proposal. Preloading these
  # avoids several queries per event.
  ICALENDAR_PROPOSAL_PRELOADS = [
    :event_type, :difficulty_level, :program,
    { track: %i[room submitter], event_schedules: :room }
  ].freeze

  # adds events to icalendar for proposals in a conference
  def icalendar_proposals(calendar, proposals, conference)
    ActiveRecord::Associations::Preloader.new(records: proposals, associations: ICALENDAR_PROPOSAL_PRELOADS).call

    proposals.each do |proposal|
      time = icalendar_proposal_time(proposal)
      # some 2021 events have nil time or event_type
      next if time.nil? || proposal.event_type.nil?

      room = icalendar_proposal_room(proposal)
      calendar.event do |e|
        e.dtstart = time
        e.dtend = time + (proposal.event_type.length * 60)
        e.duration = "PT#{proposal.event_type.length}M"
        e.created = proposal.created_at
        e.last_modified = proposal.updated_at
        e.summary = proposal.title
        e.description = proposal.abstract
        e.uid = proposal.guid
        e.url = conference_program_proposal_url(conference.short_title, proposal.id)
        v = conference.venue
        if v
          e.geo = v.latitude, v.longitude if v.latitude && v.longitude
          location = ''
          location += "#{room.name} - " if room&.name
          location += " - #{v.street}, " if v.street
          location += "#{v.postalcode} #{v.city}, " if v.postalcode && v.city
          location += "#{v.country_name}, " if v.country_name
          e.location = location
        end
        e.categories = conference.title
        e.append_categories "Difficulty: #{proposal.difficulty_level.title}" if proposal.difficulty_level.present?
        e.append_categories "Track: #{proposal.track.name}" if proposal.track.present?
      end
    end
    calendar
  end

  # The next three mirror Event#time and Event#room, but read the preloaded
  # event_schedules instead of running a query per event.
  def icalendar_event_schedule(proposal, schedule_id)
    proposal.event_schedules.find { |event_schedule| event_schedule.schedule_id == schedule_id }
  end

  def icalendar_proposal_time(proposal)
    track = proposal.track
    schedule_id = track.try(:self_organized?) ? track.selected_schedule_id : proposal.program.selected_schedule_id
    icalendar_event_schedule(proposal, schedule_id).try(:start_time)
  end

  def icalendar_proposal_room(proposal)
    if proposal.track.try(:self_organized?)
      proposal.track.room
    else
      icalendar_event_schedule(proposal, proposal.program.try(:selected_schedule_id)).try(:room)
    end
  end

  def get_happening_now_events_schedules(conference)
    HappeningNowQuery.new(conference).happening_now
  end

  def get_happening_next_events_schedules(conference)
    HappeningNowQuery.new(conference).happening_next
  end

  def load_happening_now
    query = HappeningNowQuery.new(@conference)
    events_schedules = query.happening_now
    @is_happening_next = false
    unless events_schedules.exists?
      events_schedules = query.happening_next
      @is_happening_next = true
    end
    @events_schedules_limit = Rails.configuration.conference[:events_per_page]
    @pagy, @events_schedules = pagy(events_schedules,
                                    items:      @events_schedules_limit,
                                    link_extra: 'data-remote="true"')
    @events_schedules_length = @pagy.count
  end
end
