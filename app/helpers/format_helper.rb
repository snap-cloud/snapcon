# frozen_string_literal: true

require 'redcarpet/render_strip'

module FormatHelper
  def status_icon(object)
    case object.state
    when 'new', 'to_reject', 'to_accept'
      'fa-eye'
    when 'unconfirmed', 'accepted'
      'fa-check text-muted'
    when 'confirmed'
      'fa-check text-success'
    when 'rejected', 'withdrawn', 'canceled'
      'fa-ban'
    end
  end

  def event_progress_color(progress)
    progress = progress.to_i
    if progress == 100
      'progress-bar-success'
    elsif progress >= 85
      'progress-bar-info'
    elsif progress >= 71
      'progress-bar-warning'
    else
      'progress-bar-danger'
    end
  end

  def variant_from_delta(delta, reverse: false)
    if delta.to_i.positive?
      reverse ? 'warning' : 'success'
    elsif delta.to_i.negative?
      reverse ? 'success' : 'warning'
    else
      'info'
    end
  end

  def target_progress_color(progress)
    progress = progress.to_i
    if progress >= 90
      'green'
    elsif progress < 90 && progress >= 80
      'orange'
    else
      'red'
    end
  end

  def days_left_color(days_left)
    days_left = days_left.to_i
    if days_left > 30
      'green'
    elsif days_left < 30 && days_left > 10
      'orange'
    else
      'red'
    end
  end

  def bootstrap_class_for(flash_type)
    case flash_type
    when 'success'
      'alert-success'
    when 'error'
      'alert-danger'
    when 'alert'
      'alert-warning'
    when 'notice'
      'alert-info'
    else
      'alert-warning'
    end
  end

  def label_for(event_state)
    case event_state
    when 'new'
      'label label-primary'
    when 'withdrawn', 'cancelled'
      'label label-danger'
    when 'unconfirmed', 'confirmed'
      'label label-success'
    when 'rejected'
      'label label-warning'
    end
  end

  def icon_for_todo(bool)
    bool ? 'fa-solid fa-check' : 'fa-solid fa-xmark'
  end

  def class_for_todo(bool)
    bool ? 'todolist-ok' : 'todolist-missing'
  end

  def word_pluralize(count, singular, plural = nil)
    if count.positive? && count < 2
      singular
    else
      plural || singular.pluralize
    end
  end

  # Returns black or white deppending on what of them contrast more with the
  # given color. Useful to print text in a coloured background.
  # hexcolor is a hex color of 7 characters, being the first one '#'.
  # Reference: https://24ways.org/2010/calculating-color-contrast
  def contrast_color(hexcolor)
    r = hexcolor[1..2].to_i(16)
    g = hexcolor[3..4].to_i(16)
    b = hexcolor[5..6].to_i(16)
    yiq = ((r * 299) + (g * 587) + (b * 114)) / 1000
    yiq >= 128 ? 'black' : 'white'
  end

  def td_height(rooms)
    td_height = 500 / rooms.length
    # we want all least 3 lines in events and td padding = 3px, speaker picture height >= 25px
    # and line-height = 17px => (17 * 3) + 6 + 25 = 82
    td_height < 82 ? 82 : td_height
  end

  def room_height(rooms)
    room_lines(rooms) * 17
  end

  def room_lines(rooms)
    # line-height = 17px, td padding = 3px
    (td_height(rooms) - 6) / 17
  end

  def event_height(rooms)
    event_lines(rooms) * 17
  end

  def event_lines(rooms)
    # line-height = 17px, td padding = 3px, speaker picture height >= 25px
    (td_height(rooms) - 31) / 17
  end

  def speaker_height(rooms)
    # td padding = 3px
    speaker_height = td_height(rooms) - 6 - event_height(rooms)
    # The speaker picture is a circle and the width must be <= 37 to avoid making the cell widther
    speaker_height >= 37 ? 37 : speaker_height
  end

  def speaker_width(rooms)
    # speaker picture padding: 4px 2px; and we want the picture to be a circle
    speaker_height(rooms) - 4
  end

  def selected_scheduled?(schedule)
    schedule == @selected_schedule ? 'Yes' : 'No'
  end

  def markdown(text, escape_html = true)
    return '' if text.nil?

    markdown_options = {
      autolink:                     true,
      space_after_headers:          true,
      # no_intra_emphasis:            true, # SNAPCON
      fenced_code_blocks:           true,
      disable_indented_code_blocks: true,
      tables:                       true, # SNAPCON
      strikethrough:                true, # SNAPCON
      footnotes:                    true, # SNAPCON
      superscript:                  true # SNAPCON
    }
    render_options = {
      escape_html:     escape_html,
      safe_links_only: true
    }
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(render_options), markdown_options)
    rendered = sanitize(markdown.render(text))
    escape_html ? sanitize(rendered, scrubber: Loofah::Scrubbers::NoFollow.new) : rendered.html_safe
  end

  def markdown_hint(text = '')
    link = link_to('**Markdown Syntax**',
                   'https://daringfireball.net/projects/markdown/syntax',
                   target: '_blank', rel: 'noopener')
    markdown("#{text} Please look at #{link} to format your text", false)
  end

  # Return a plain text markdown stripped of formatting.
  def plain_text(content)
    Redcarpet::Markdown.new(Redcarpet::Render::StripDown).render(content)
  end

  def quantity_left_of(resource)
    return '-/-' if resource.quantity.blank?

    "#{resource.quantity - resource.used}/#{resource.quantity}"
  end
end
