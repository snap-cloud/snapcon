# frozen_string_literal: true

# TODO: Split this module into smaller modules
# rubocop:disable Metrics/ModuleLength
module EventsHelper
  ##
  # Includes functions related to events
  ##
  ##
  # ====Returns
  # * +String+ -> number of registrations / max allowed registrations
  def registered_text(event)
    return "Registered: #{event.registrations.count}/#{event.max_attendees}" if event.max_attendees

    "Registered: #{event.registrations.count}"
  end

  # TODO-SNAPCON: Move to admin helper
  def rating_stars(rating, max, options = {})
    Array.new(max) do |counter|
      content_tag(
        'label',
        '',
        class: "rating#{' bright' if rating.to_f > counter}",
        **options
      )
    end.join.html_safe
  end

  # TODO-SNAPCON: Move to admin helper
  def rating_fraction(rating, max, options = {})
    content_tag('span', "#{rating}/#{max}", **options)
  end

  def replacement_event_notice(event_schedule, styles: '')
    if event_schedule.present? && event_schedule.replacement?(@withdrawn_event_schedules)
      replaced_event = event_schedule.replaced_event_schedule.try(:event)
      content_tag :span do
        concat content_tag :span, 'Please note that this event replaces '
        concat link_to replaced_event.title, conference_program_proposal_path(@conference.short_title, replaced_event.id), style: styles
      end
    end
  end

  def canceled_replacement_event_label(event, event_schedule, *label_classes)
    if event.state == 'canceled' || event.state == 'withdrawn'
      content_tag :span, 'CANCELED', class: (['label', 'label-danger'] + label_classes)
    elsif event_schedule.present? && event_schedule.replacement?(@withdrawn_event_schedules)
      content_tag :span, 'REPLACEMENT', class: (['label', 'label-info'] + label_classes)
    end
  end

  def track_selector_input(form)
    if @program.tracks.confirmed.cfp_active.any?
      form.input :track_id, as:            :select,
                            collection:    @program.tracks.confirmed.cfp_active.pluck(:name, :id),
                            include_blank: '(Please select)'
    end
  end

  # TODO-SNAPCON: Move to admin helper
  def rating_tooltip(event, max_rating)
    "#{event.average_rating}/#{max_rating}, #{pluralize(event.voters.length, 'vote')}"
  end

  def event_type_options(event_types)
    event_types.map do |type|
      [
        "#{type.title} - #{show_time(type.length)}",
        type.id,
        data: {
          min_words:    type.minimum_abstract_length,
          max_words:    type.maximum_abstract_length,
          instructions: type.submission_instructions
        }
      ]
    end
  end

  # TODO-SNAPCON: Move to admin helper
  def event_type_dropdown(event, event_types, conference_id)
    selection = event.event_type.try(:title) || 'Event Type'
    options = event_types.collect do |event_type|
      [
        event_type.title,
        admin_conference_program_event_path(
          conference_id,
          event,
          event: { event_type_id: event_type.id }
        )
      ]
    end
    active_dropdown(selection, options)
  end

  # TODO-SNAPCON: Move to admin helper
  def track_dropdown(event, tracks, conference_id)
    selection = event.track.try(:name) || 'Track'
    options = tracks.collect do |track|
      [
        track.name,
        admin_conference_program_event_path(
          conference_id,
          event,
          event: { track_id: track.id }
        )
      ]
    end
    active_dropdown(selection, options)
  end

  # TODO-SNAPCON: Move to admin helper
  def difficulty_dropdown(event, difficulties, conference_id)
    selection = event.difficulty_level.try(:title) || 'Difficulty'
    options = difficulties.collect do |difficulty|
      [
        difficulty.title,
        admin_conference_program_event_path(
          conference_id,
          event,
          event: { difficulty_level_id: difficulty.id }
        )
      ]
    end
    active_dropdown(selection, options)
  end

  # TODO-SNAPCON: Move to admin helper
  def state_dropdown(event, conference_id, email_settings)
    selection = event.state.humanize
    options = []
    if event.transition_possible? :accept
      options << [
        'Accept',
        accept_admin_conference_program_event_path(conference_id, event)
      ]
      if email_settings.send_on_accepted?
        options << [
          'Accept (without email)',
          accept_admin_conference_program_event_path(
            conference_id,
            event,
            send_mail: false
          )
        ]
      end
    end
    if event.transition_possible? :reject
      options << [
        'Reject',
        reject_admin_conference_program_event_path(conference_id, event)
      ]
      if email_settings.send_on_rejected?
        options << [
          'Reject (without email)',
          reject_admin_conference_program_event_path(
            conference_id,
            event,
            send_mail: false
          )
        ]
      end
    end
    if event.transition_possible? :restart
      options << [
        'Start review',
        restart_admin_conference_program_event_path(conference_id, event)
      ]
    end
    if event.transition_possible? :confirm
      options << [
        'Confirm',
        confirm_admin_conference_program_event_path(conference_id, event)
      ]
    end
    if event.transition_possible? :cancel
      options << [
        'Cancel',
        cancel_admin_conference_program_event_path(conference_id, event)
      ]
    end
    active_dropdown(selection, options)
  end

  # TODO-SNAPCON: Move to admin helper
  def event_switch_checkbox(event, attribute, conference_id)
    check_box_tag(
      conference_id,
      event.id,
      event.send(attribute),
      url:   admin_conference_program_event_path(
        conference_id,
        event,
        event: { attribute => nil }
      ),
      class: 'switch-checkbox'
    )
  end

  def event_favourited?(event, current_user)
    return false unless current_user

    event.favourite_users.exists?(current_user.id)
  end

  def timezone_offset(conference)
    Time.now.in_time_zone(conference.timezone).utc_offset / 1.hour
  end

  def timezone_text(object)
    Time.now.in_time_zone(object.timezone).strftime('%Z')
  end

  def join_event_link(event, event_schedule, current_user)
    return unless current_user && event_schedule && event_schedule.room_url.present?
    # return if event_schedule.ended?

    conference = event.conference
    is_now = event_schedule.happening_now? # 30 minute threshold.
    is_registered = conference.user_registered?(current_user)
    admin = current_user.roles.where(id: conference.roles).any?
    # is_presenter = event.speakers.include?(current_user) || event.volunteers.include?(current_user)

    if admin || (is_now && is_registered)
      link_to("Join Event Now #{'(Early)' unless is_now}",
              join_conference_program_proposal_path(conference, event),
              target: '_blank', class: 'btn btn-primary',
              'aria-label': "Join #{event.title}")
    elsif is_registered
      content_tag :span, class: 'btn btn-default btn-xs disabled' do
        'Click to Join During Event'
      end
    else
      link_to('Register for the conference to join this event.',
              conference_conference_registration_path(conference),
              class:        'btn btn-default btn-xs',
              'aria-label': "Register for #{event.title}")
    end
  end

  def calendar_timestamp(timestamp, _timezone)
    timestamp = timestamp.in_time_zone('GMT')
    timestamp -= timestamp.utc_offset
    timestamp.strftime('%Y%m%dT%H%M%S')
  end

  def google_calendar_link(event_schedule)
    event = event_schedule.event
    conference = event.conference
    calendar_base = 'https://www.google.com/calendar/render'
    start_timestamp = calendar_timestamp(event_schedule.start_time, conference.timezone)
    end_timestamp = calendar_timestamp(event_schedule.end_time, conference.timezone)
    event_details = {
      action:   'TEMPLATE',
      text:     "#{event.title} at #{conference.title}",
      details:  calendar_event_text(event, event_schedule, conference),
      location: "#{event_schedule.room.name} #{event_schedule.room_url}",
      dates:    "#{start_timestamp}/#{end_timestamp}",
      ctz:      event_schedule.timezone
    }
    "#{calendar_base}?#{event_details.to_param}"
  end

  def css_background_color(color)
    "background-color: #{color}; color: #{contrast_color(color)};"
  end

  private

  def calendar_event_text(event, event_schedule, conference)
    <<~TEXT
      #{conference.title} - #{event.title}
      #{event_schedule.start_time.strftime('%Y %B %e - %H:%M')} #{event_schedule.timezone}

      More Info: #{conference_program_proposal_url(conference, event)}
      Join: #{event.url}

      #{truncate(event.abstract, length: 200)}
    TEXT
  end

  def active_dropdown(selection, options)
    # Consistent rendering of dropdown lists that submit patched changes
    #
    # Selection is the string to show by default, which is clicked to expose the
    # dropdown options.
    # Options is a list of 2-item lists; for each entry:
    # * [0] is the text of the option,
    # * [1] is the link url for the options
    content_tag('div', class: 'dropdown') do
      content_tag(
        'a',
        class: 'dropdown-toggle',
        href:  '#',
        data:  { toggle: 'dropdown' }
      ) do
        content_tag('span', selection) +
          content_tag('span', '', class: 'caret')
      end +
        content_tag('ul', class: 'dropdown-menu') do
          options.collect do |option|
            content_tag('li', link_to(option[0], option[1], method: :patch))
          end.join.html_safe
        end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
