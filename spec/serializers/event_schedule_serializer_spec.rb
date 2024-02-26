# frozen_string_literal: true

# == Schema Information
#
# Table name: event_schedules
#
#  id          :bigint           not null, primary key
#  enabled     :boolean          default(TRUE)
#  start_time  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :integer
#  room_id     :integer
#  schedule_id :integer
#
# Indexes
#
#  index_event_schedules_on_event_id                  (event_id)
#  index_event_schedules_on_event_id_and_schedule_id  (event_id,schedule_id) UNIQUE
#  index_event_schedules_on_room_id                   (room_id)
#  index_event_schedules_on_schedule_id               (schedule_id)
#
require 'spec_helper'

describe EventScheduleSerializer, type: :serializer do
  let(:start) { DateTime.new(2000, 1, 2, 3, 4, 5) }
  let(:timezone) { 'Etc/GMT+11' }
  let(:conference) do
    create(:conference, start_date: start.to_date,
                        start_hour: start.hour,
                        timezone:   timezone)
  end
  let(:program) { create(:program, conference: conference) }
  let(:event) { create(:event, program: program) }
  let(:event_schedule) { create(:event_schedule, event: event, start_time: start) }
  let(:serializer) { described_class.new(event_schedule) }

  it 'sets date and room' do
    expected_json = {
      date: '2000-01-02T03:04:05.000-11:00',
      room: event_schedule.room.guid
    }.to_json

    expect(serializer.to_json).to eq expected_json
  end
end
