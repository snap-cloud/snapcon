class FullCalendarFormatter
  def self.rooms_to_resources(rooms)
    rooms.map { |room| room_to_resource(room) }.to_json
  end

  def self.event_schedules_to_resources(event_schedules)
    return '[]' if event_schedules.empty?

    conference = event_schedules.first.schedule.program.conference
    event_schedules.map { |event_schedule| event_schedule_to_resource(conference, event_schedule) }.to_json
  end

  class << self
    include FormatHelper

    private

    def room_to_resource(room)
      {
        id:    room.guid,
        title: room.name,
        order: room.order
      }
    end

    def event_schedule_to_resource(conference, event_schedule)
      event = event_schedule.event
      event_type_color = event.event_type.color
      url = Rails.application.routes.url_helpers.conference_program_proposal_path(conference.short_title, event.id)
      background_event = event.event_type.title.match(/Break/i)
      rooms = background_event ? conference.venue.rooms.pluck(:guid) : [event_schedule.room.guid]

      {
        id:              event.guid,
        title:           event.title,
        start:        event_schedule.start_time_in_conference_timezone.iso8601,
        end:          event_schedule.end_time_in_conference_timezone.iso8601,
        resourceIds:     rooms,
        url:             url,
        borderColor:     event_type_color,
        backgroundColor: event_type_color,
        textColor:       contrast_color(event_type_color),
        className:       "fc-event-track-#{event.track&.short_name || 'none'}",
        display:         background_event ? 'background' : 'auto'
      }
    end
  end
end
