# frozen_string_literal: true

class EventDuplicator
  def initialize(event, submitter = nil)
    @event = event
    @submitter = submitter
  end

  def duplicate(count = 1)
    duplicated_events = []
    count.times do
      duplicated_events << create_duplicate
    end
    duplicated_events
  end

  private

  def create_duplicate
    duplicate_event = Event.create!(
      # Content fields
      title:                        @event.title,
      subtitle:                     @event.subtitle,
      abstract:                     @event.abstract,
      description:                  @event.description,
      submission_text:              @event.submission_text,
      committee_review:             @event.committee_review,
      proposal_additional_speakers: @event.proposal_additional_speakers,
      event_type:                   @event.event_type,
      track:                        @event.track,
      difficulty_level:             @event.difficulty_level,
      language:                     @event.language,
      presentation_mode:            @event.presentation_mode,
      require_registration:         @event.require_registration,
      max_attendees:                @event.max_attendees,
      program:                      @event.program,
      state:                        'new',
      progress:                     @event.progress,
      public:                       @event.public,
      is_highlight:                 @event.is_highlight,
      superevent:                   @event.superevent,

      # Don't copy: start_time, room_id, parent_id (reset to nil)
      start_time:                   nil,
      room_id:                      nil,
      parent_id:                    nil,

      # Submitter
      submitter:                    @submitter
    )

    # Copy speakers and volunteers
    duplicate_event.speakers = @event.speakers
    duplicate_event.volunteers = @event.volunteers
    duplicate_event.save!

    duplicate_event
  end
end
