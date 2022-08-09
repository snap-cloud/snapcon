# frozen_string_literal: true

module EventTypesHelper
  ##
  # Includes functions related to event_types
  ##
  ##
  # ====Returns
  # * +String+ -> number of registrations / max allowed registrations
  def event_type_select_options(event_types = {})
    event_types.map do |type|
      [
        "#{type.title} - #{show_time(type.length)}",
        type.id,
        { data: {
          min_words:    type.minimum_abstract_length,
          max_words:    type.maximum_abstract_length,
          instructions: type.submission_instructions
        } }
      ]
    end
  end
end
