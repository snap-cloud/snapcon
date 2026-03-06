# frozen_string_literal: true

class EventDuplicator
  def initialize(event)
    @event = event
  end

  def duplicate
    Event.create!(
      title:                @event.title,
      abstract:             @event.abstract,
      description:          @event.description,
      event_type:           @event.event_type,
      track:                @event.track,
      require_registration: @event.require_registration,
      max_attendees:        @event.max_attendees,
      program:              @event.program,
      state:                'new',
      start_time:           nil,
      room_id:              nil,
      parent_id:            nil
    )
  end
end
