# frozen_string_literal: true

namespace :events_registrations do
  desc 'Deletes duplicate entries'
  task deduplicate: :environment do
    if ActiveRecord::Migrator.get_all_versions.include? 20_160_403_214_841
      duplicates = EventsRegistration.all.map { |er| er.id if er.valid? == false }.compact

      puts "Duplicates found: #{duplicates.count}"
      puts "With IDs: #{duplicates}" if duplicates.count > 0

      EventsRegistration.all.each do |er|
        records = EventsRegistration.where(registration_id: er.registration_id, event_id: er.event_id)
        next unless records.count > 1

        # Iterate through duplicates (excluding 1st record)
        (1..(records.count - 1)).each do |i|
          puts "Deleting EventsRegistration record with ID #{records[i].id} ..."
          if records[i].destroy
            puts 'Succeeded!'
          else
            puts 'Faild!'
          end
        end
      end
    else
      puts 'Please migrate to run this task. Make sure your migration include 20160403214841'
    end
  end
end
