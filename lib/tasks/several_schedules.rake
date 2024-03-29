# frozen_string_literal: true

namespace :data do
  desc 'Move the start_time and room attributes from Event to EventSchedule'

  task move_events_attributes: :environment do
    Program.all.each do |program|
      schedule = Schedule.create(program:)
      program.selected_schedule = schedule unless program.selected_schedule
      program.save!
      program.events.each do |event|
        next if event.start_time.nil? && event.room_id.nil?

        # we can not use .room as this relation has been removed
        EventSchedule.create(event:,
                             schedule:,
                             start_time: event.start_time,
                             room_id:    event.room_id)
        event.start_time = nil
        event.room_id = nil
        event.save
      end
    end
    puts 'The start_time and room attributes has been moved from Event to EventSchedule'
  end
end
