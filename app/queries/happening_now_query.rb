# frozen_string_literal: true

# Finds the event schedules for a conference's "Happening Now" section.
#
# Filters in SQL instead of loading every event schedule in the program (with
# its event, speakers, track, room, etc.) and filtering in Ruby.
#
#   query = HappeningNowQuery.new(conference)
#   query.happening_now  # => relation of sessions on now, or within 15 minutes
#   query.happening_next # => relation of sessions at the next start time
#
# Covers the program's selected schedule and the selected schedules of
# confirmed self-organized tracks, like Program#selected_event_schedules.
#
# Times: event_schedules.start_time holds the conference's local wall-clock
# time in a UTC column (see the TODOs in EventSchedule#happening_now?). So we
# compare it with the current wall-clock time in the conference's time zone.
class HappeningNowQuery
  THRESHOLD = 15.minutes

  # Associations the happening now views use.
  INCLUDES = [:room, { event: %i[event_type speakers speaker_event_users track program] }].freeze

  def initialize(conference, now: Time.current)
    @conference = conference
    @now = now
  end

  # Sessions that overlap the window from 15 minutes ago to 15 minutes from
  # now, and haven't ended yet.
  def happening_now
    scope
      .where('event_schedules.start_time <= ?', local_now + THRESHOLD)
      .where("event_schedules.start_time + event_types.length * INTERVAL '1 minute' >= ?", local_now)
  end

  # Sessions starting at the next start time from now (several can share it).
  def happening_next
    upcoming = base.where('event_schedules.start_time >= ?', local_now)
    next_start = upcoming.minimum(:start_time)
    return EventSchedule.none if next_start.nil?

    scope.where(start_time: next_start)
  end

  private

  attr_reader :conference, :now

  def scope
    base
      .includes(*INCLUDES)
      .order(:start_time)
      .order(Room.arel_table[:order].asc)
  end

  def base
    EventSchedule
      .where(schedule_id: schedule_ids)
      .joins(event: :event_type)
      .left_joins(:room)
  end

  def schedule_ids
    program = conference.program
    return [] unless program

    track_schedule_ids = program.tracks.self_organized.confirmed.where.not(selected_schedule_id: nil)
                                .pluck(:selected_schedule_id)
    [program.selected_schedule_id, *track_schedule_ids].compact
  end

  # The conference's current wall-clock time, as a UTC time, to compare with
  # start_time.
  def local_now
    @local_now ||= begin
      local = now.in_time_zone(conference.timezone)
      local.utc + local.utc_offset
    end
  end
end
