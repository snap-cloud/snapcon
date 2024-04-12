# frozen_string_literal: true

require 'spec_helper'

describe ApplicationHelper, type: :helper do
  let(:conference) { create(:full_conference) }
  let(:event) { create(:event, program: conference.program) }
  let(:sponsor) { create(:sponsor) }

  describe '#date_string' do
    it 'when conference lasts 1 day' do
      expect(date_string('Sun, 19 Feb 2017'.to_time, 'Sun, 19 Feb 2017'.to_time)).to eq 'February 19 2017'
    end

    it 'when conference starts and ends in the same month and year' do
      expect(date_string('Sun, 19 Feb 2017'.to_time, 'Tue, 28 Feb 2017'.to_time)).to eq 'February 19 - 28, 2017'
    end

    it 'when conference ends in another month, of the same year' do
      expect(date_string('Sun, 19 Feb 2017'.to_time, 'Tue, 28 March 2017'.to_time)).to eq 'February 19 - March 28, 2017'
    end

    it 'when conference ends in another month, of a different year' do
      expect(date_string('Sun, 19 Feb 2017'.to_time,
                         'Sun, 12 March 2018'.to_time)).to eq 'February 19, 2017 - March 12, 2018'
    end
  end

  describe '#concurrent_events' do
    before do
      @other_event = create(:event, program: conference.program, state: 'confirmed')
      schedule = create(:schedule, program: conference.program)
      conference.program.update_attribute(:selected_schedule, schedule)
      @event_schedule = create(:event_schedule, event: event,
start_time: conference.start_date + conference.start_hour.hours, room: create(:room), schedule: schedule)
      @other_event_schedule = create(:event_schedule, event: @other_event,
start_time: conference.start_date + conference.start_hour.hours, room: create(:room), schedule: schedule)
    end

    describe 'does return correct concurrent events' do
      it 'when events starts at the same time' do
        expect(concurrent_events(event).include?(@other_event)).to be true
      end

      it 'when event is in between the other event' do
        @event_schedule.update_attribute(:start_time, @other_event_schedule.start_time + 10.minutes)
        expect(concurrent_events(event).include?(@other_event)).to be true
      end
    end

    describe 'does not return as concurrent event' do
      it 'when event is not scheduled' do
        @event_schedule.destroy
        expect(concurrent_events(event).present?).to be false
      end

      it 'when one event starts and other ends at the same time' do
        @event_schedule.update_attribute(:start_time, @other_event_schedule.end_time)
        expect(concurrent_events(event).present?).to be false
      end

      it 'when conference program does not have a selected schedule' do
        conference.program.update_attribute(:selected_schedule_id, nil)
        expect(concurrent_events(event).present?).to be false
      end
    end

    describe 'navigation image link' do
      it 'defaults to OSEM' do
        ENV.delete('OSEM_NAME')
        expect(nav_root_link_for(nil)).to include image_tag('snapcon_logo.png', alt: 'OSEM')
      end

      it 'uses the conference organization name' do
        expect(nav_root_link_for(conference)).to include image_tag(conference.picture.thumb.url,
                                                                   alt: conference.organization.name)
      end
    end

    describe 'navigation link title text' do
      it 'defaults to OSEM' do
        ENV.delete('OSEM_NAME')
        expect(nav_link_text(nil)).to match 'OSEM'
      end

      it 'uses the environment variable' do
        ENV['OSEM_NAME'] = Faker::Company.name + "'"
        expect(nav_link_text(nil)).to match ENV.fetch('OSEM_NAME', nil)
      end

      it 'uses the conference organization name' do
        expect(nav_link_text(conference)).to match conference.organization.name
      end
    end
  end

  describe '#get_logo' do
    context 'first sponsorship_level' do
      before do
        first_sponsorship_level = create(:sponsorship_level, position: 1)
        sponsor.update_attribute(:sponsorship_level, first_sponsorship_level)
      end

      it 'returns correct url' do
        expect(get_logo(sponsor)).to match %r{.*(\bfirst/#{sponsor.logo_file_name}\b)}
      end
    end

    context 'second sponsorship_level' do
      before do
        second_sponsorship_level = create(:sponsorship_level, position: 2)
        sponsor.update_attribute(:sponsorship_level, second_sponsorship_level)
      end

      it 'returns correct url' do
        expect(get_logo(sponsor)).to match %r{.*(\bsecond/#{sponsor.logo_file_name}\b)}
      end
    end

    context 'other sponsorship_level' do
      before do
        other_sponsorship_level = create(:sponsorship_level, position: 3)
        sponsor.update_attribute(:sponsorship_level, other_sponsorship_level)
      end

      it 'returns correct url' do
        expect(get_logo(sponsor)).to match %r{.*(\bothers/#{sponsor.logo_file_name}\b)}
      end
    end

    context 'non-sponsor' do
      it 'returns correct url' do
        expect(get_logo(conference)).to match %r{.*(\blarge/#{conference.logo_file_name}\b)}
      end
    end
  end

  describe '#conference_logo_url' do
    let(:organization) { create(:organization) }
    let(:conference2) { create(:conference, organization: organization) }

    it 'gives the correct logo url' do
      expect(conference_logo_url(conference2)).to eq('snapcon_logo.png')

      File.open('spec/support/logos/1.png') do |file|
        organization.picture = file
      end

      expect(conference_logo_url(conference2)).to include(organization.picture.thumb.url)

      File.open('spec/support/logos/2.png') do |file|
        conference2.picture = file
      end

      expect(conference_logo_url(conference2)).to include('2.png')
    end
  end

  describe '#event_type_sentence' do 
    before do 
      create(:event_type, title: 'Keynote', program: conference.program, enable_public_submission: false)
    end 

    context 'when a user is an admin' do 
      it 'returns a sentence with all event types' do 
        expect(helper.event_types_sentence(conference, true)).to eq 'Talks, Workshops, and Keynotes'
      end 
    end 

    context 'when a user is not an admin' do 
      it 'returns a sentence only event types that allow public submission' do 
        expect(helper.event_types_sentence(conference, false)).to eq 'Talks and Workshops'
      end 
    end 
  end 
end
