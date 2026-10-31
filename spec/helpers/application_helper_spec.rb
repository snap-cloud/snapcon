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
        expect(nav_root_link_for(nil)).to include image_tag('snapcon_logo.png', alt: 'OSEM homepage')
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
    let(:conference2) { create(:conference) }

    it 'gives the correct logo url' do
      expect(conference_logo_url(conference2)).to eq('snapcon_logo.png')

      File.open('spec/support/logos/2.png') do |file|
        conference2.picture = file
      end

      expect(conference_logo_url(conference2)).to include('2.png')
    end
  end

  describe '#visible_conference_links' do
    let!(:old_public) do
      create(:conference, start_date: 3.years.ago.to_date, end_date: 3.years.ago.to_date + 2.days,
                          splashpage: build(:splashpage, public: true))
    end
    let!(:new_public) do
      create(:conference, start_date: 1.month.from_now.to_date, end_date: 1.month.from_now.to_date + 2.days,
                          splashpage: build(:splashpage, public: true))
    end
    let!(:mid_private) do
      create(:conference, start_date: 1.year.ago.to_date, end_date: 1.year.ago.to_date + 2.days,
                          splashpage: build(:splashpage, public: false))
    end
    let!(:no_splashpage) do
      create(:conference, start_date: 2.years.ago.to_date, end_date: 2.years.ago.to_date + 2.days)
    end

    def links_for(user)
      ability = Ability.new(user)
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?) { |*args| ability.can?(*args) }
      helper.visible_conference_links
    end

    it 'shows guests only conferences with a public splashpage, newest first' do
      expect(links_for(nil)).to eq [new_public, old_public]
    end

    it 'shows signed in users without roles only public conferences' do
      expect(links_for(create(:user))).to eq [new_public, old_public]
    end

    it 'also shows organizers their own private conference' do
      organizer = create(:organizer, resource: mid_private)
      expect(links_for(organizer)).to eq [new_public, mid_private, old_public]
    end

    it 'does not show cfp team members their private conference (Ability only grants that to organizers)' do
      cfp_user = create(:cfp_user, resource: no_splashpage)
      expect(links_for(cfp_user)).to eq [new_public, old_public]
    end

    it 'shows admins every conference, newest first' do
      expect(links_for(create(:admin))).to eq [new_public, mid_private, no_splashpage, old_public]
    end

    it 'matches the per-conference CanCan check for every kind of user' do
      organizer = create(:organizer, resource: mid_private)
      [nil, create(:user), organizer, create(:admin)].each do |user|
        ability = Ability.new(user)
        expected = Conference.unscoped.order(start_date: :desc).select { |conf| ability.can?(:show, conf) }
        helper.instance_variable_set(:@visible_conference_links, nil)
        expect(links_for(user)).to eq expected
      end
    end

    it 'only loads the columns the nav needs for guests' do
      conf = links_for(nil).first
      expect(conf.attributes.keys).to contain_exactly('id', 'title', 'short_title', 'start_date')
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
