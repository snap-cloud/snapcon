# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                           :bigint           not null, primary key
#  abstract                     :text
#  comments_count               :integer          default(0), not null
#  committee_review             :text
#  description                  :text
#  guid                         :string           not null
#  is_highlight                 :boolean          default(FALSE)
#  language                     :string
#  max_attendees                :integer
#  presentation_mode            :integer
#  progress                     :string           default("new"), not null
#  proposal_additional_speakers :text
#  public                       :boolean          default(TRUE)
#  require_registration         :boolean
#  start_time                   :datetime
#  state                        :string           default("new"), not null
#  submission_text              :text
#  subtitle                     :string
#  superevent                   :boolean
#  title                        :string           not null
#  week                         :integer
#  created_at                   :datetime
#  updated_at                   :datetime
#  difficulty_level_id          :integer
#  event_type_id                :integer
#  parent_id                    :integer
#  program_id                   :integer
#  room_id                      :integer
#  track_id                     :integer
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => events.id)
#
require 'spec_helper'
describe EventSerializer, type: :serializer do
  let(:conference) { create(:conference, timezone: 'UTC') }
  let(:program) { create(:program, conference: conference) }
  let(:event) do
    create(:event, program:  program,
                   title:    'Some Talk',
                   abstract: 'Lorem ipsum dolor sit amet')
  end
  let(:serializer) { EventSerializer.new(event) }

  context 'event does not have date, room and tracks assigned' do
    it 'sets guid, title, length, abstract and type' do
      expected_json = {
        guid:           event.guid,
        url:            "http://localhost:3000/conferences/#{event.conference.short_title}/program/proposals/#{event.id}",
        title:          'Some Talk',
        length:         30,
        scheduled_date: nil,
        language:       nil,
        abstract:       'Lorem ipsum dolor sit amet',
        speaker_ids:    event.speaker_ids,
        type:           'Example Event Type',
        room:           nil,
        track:          nil
      }.to_json

      expect(serializer.to_json).to eq expected_json
    end
  end

  context 'event has date, speakers, room and tracks assigned' do
    let(:speaker) { create(:user) }
    let(:room) { create(:room) }
    let(:track) { create(:track) }

    before do
      event.language = 'English'
      event.speakers = [speaker]
      create(:event_schedule, event: event, room: room, start_time: Date.new(2014, 3, 4) + 9.hours)
      event.track = track
    end

    it 'sets guid, title, length, abstract, type, date, language, speakers, room and track' do
      expected_json = {
        guid:           event.guid,
        url:            "http://localhost:3000/conferences/#{event.conference.short_title}/program/proposals/#{event.id}",
        title:          'Some Talk',
        length:         30,
        scheduled_date: '2014-03-04T09:00:00.000Z',
        language:       'English',
        abstract:       'Lorem ipsum dolor sit amet',
        speaker_ids:    [speaker.id],
        type:           'Example Event Type',
        room:           room.guid,
        track:          track.guid
      }.to_json

      expect(serializer.to_json).to eq expected_json
    end
  end
end
