# frozen_string_literal: true

require 'spec_helper'

describe Event do
  let!(:conference) { create(:conference, :with_splashpage) }
  let!(:registration_period) { create(:registration_period, conference: conference, start_date: Date.current) }
  let!(:cfp) { create(:cfp, program_id: conference.program.id) }
  let!(:organizer) { create(:organizer, resource: conference) }
  let!(:participant) { create(:user) }
  let!(:participant_without_bio) { create(:user, biography: '') }

  before do
    @options = {}
    @options[:send_mail] = 'false'
    @event = create(:event, program: conference.program, title: 'Example Proposal')
    @event.event_users.create(user: participant, event_role: 'submitter')
    @event.event_users.create(user: participant, event_role: 'speaker')
  end

  after do
    sign_out
  end

  context 'as an conference organizer' do
    before do
      sign_in organizer
    end

    it 'can preview a proposal if it is public', feature: true, js: true do
      visit admin_conference_program_event_path(conference.short_title, @event)
      expect(page).to have_selector(:link_or_button, 'Preview')
      click_link 'Preview'
      expect(page).to have_current_path(conference_program_proposal_path(conference.short_title, @event.id),
                                        ignore_query: true)
    end

    it 'cannot preview a proposal if it is not public', feature: true, js: true do
      event = create(:event, program: conference.program, title: 'Example Proposal')
      event.public = false
      event.save!
      visit admin_conference_program_event_path(conference.short_title, event)
      expect(page).not_to have_selector(:link_or_button, 'Preview')
    end

    it 'rejects a proposal', feature: true, js: true do
      visit admin_conference_program_events_path(conference.short_title)
      expect(page).to have_content 'Example Proposal'

      click_on 'New'
      click_link 'Reject'
      expect(page).to have_content 'Event rejected!'
      @event.reload
      expect(@event.state).to eq('rejected')
    end

    it 'accepts a proposal', feature: true, js: true do
      visit admin_conference_program_events_path(conference.short_title)
      expect(page).to have_content 'Example Proposal'

      click_on 'New'
      click_link 'Accept'
      expect(page).to have_content 'Event accepted!'
      expect(page).to have_content 'Unconfirmed'
      @event.reload
      expect(@event.state).to eq('unconfirmed')
    end

    it 'restarts review of a proposal', feature: true, js: true do
      @event.reject!(@options)
      visit admin_conference_program_events_path(conference.short_title)
      expect(page).to have_content 'Example Proposal'

      click_on 'Rejected'
      click_link 'Start review'
      expect(page).to have_content 'Review started!'
      @event.reload
      expect(@event.state).to eq('new')
    end
  end

  context 'as a participant' do
    before do
      @event.accept!(@options)
    end

    it 'not signed_in user submits proposal' do
      expected_count_event = Event.count + 1
      expected_count_user = User.count + 1

      visit new_conference_program_proposal_path(conference.short_title)
      within('#signup') do
        fill_in 'user_username', with: 'Test User'
        fill_in 'user_email', with: 'testuser@osem.io'
        fill_in 'user_password', with: 'testuserpassword'
        fill_in 'user_password_confirmation', with: 'testuserpassword'
      end
      fill_in 'event_title', with: 'Example Proposal'
      select('Example Event Type', from: 'event[event_type_id]')
      fill_in 'event_abstract', with: 'Lorem ipsum abstract'
      fill_in 'event_submission_text', with: 'Lorem ipsum submission'

      click_button 'Create Proposal'
      page.find('#flash')
      expect(page).to have_content 'Proposal was successfully submitted.'

      expect(Event.count).to eq(expected_count_event)
      expect(User.count).to eq(expected_count_user)
    end

    it 'edit proposal without cfp' do
      conference = create(:conference)
      proposal = create(:event, program: conference.program)

      sign_in proposal.submitter

      visit edit_conference_program_proposal_path(proposal.program.conference.short_title, proposal)

      expect(page).to have_content 'Proposal Information'
    end

    it 'update a proposal' do
      conference = create(:conference)
      create(:cfp, program: conference.program)
      proposal = create(:event, program: conference.program)

      sign_in proposal.submitter

      visit edit_conference_program_proposal_path(proposal.program.conference.short_title, proposal)

      fill_in 'event_subtitle', with: 'My event subtitle'
      select('Easy', from: 'event[difficulty_level_id]')

      click_button 'Update Proposal'
      page.find('#flash')
      expect(page).to have_content 'Proposal was successfully updated.'
    end

    it 'signed_in user submits a valid proposal', feature: true, js: true do
      sign_in participant_without_bio
      expected_count = Event.count + 1

      visit conference_program_proposals_path(conference.short_title)
      click_link 'New Proposal'
      expect(page).to have_selector(".in[id='#{find_field('event[event_type_id]').value}-help']") # End of animation

      fill_in 'event_title', with: 'Example Proposal'
      select('Example Event Type', from: 'event[event_type_id]')
      expect(page).to have_selector(".in[id='#{find_field('event[event_type_id]').value}-help']") # End of animation

      expect(page).to have_text('Example Event Description')
      fill_in 'event_abstract', with: 'Lorem ipsum abstract'
      expect(page).to have_text('You have used 3 words')

      fill_in 'event_submission_text', with: 'Lorem ipsum submission_text'
      expect(page).to have_text('Submission text')
      # Submission Instructions content
      expect(page).to have_text('Example Event Instructions')

      # TODO-SNAPCON: (mb) this field is always shown.
      # click_link 'Do you require something special for your event?'
      fill_in 'event_description', with: 'Lorem ipsum description'

      click_button 'Create Proposal'

      page.find('#flash')
      expect(page).to have_content 'Proposal was successfully submitted.'
      expect(page).to have_current_path(conference_program_proposals_path(conference.short_title), ignore_query: true)
      expect(Event.count).to eq(expected_count)
    end

    it 'confirms a proposal', feature: true, js: true do
      sign_in participant
      visit conference_program_proposals_path(conference.short_title)
      expect(page).to have_content 'Example Proposal'
      expect(@event.state).to eq('unconfirmed')
      click_link "confirm_proposal_#{@event.id}"
      expect(page).to have_content 'The proposal was confirmed. Please register to attend the conference.'
      expect(page).to have_current_path(new_conference_conference_registration_path(conference.short_title),
                                        ignore_query: true)
      @event.reload
      expect(@event.state).to eq('confirmed')
    end

    it 'withdraw a proposal', feature: true, js: true do
      sign_in participant
      @event.confirm!
      visit conference_program_proposals_path(conference.short_title)
      expect(page).to have_content 'Example Proposal'
      click_link "delete_proposal_#{@event.id}"
      page.accept_alert
      page.find('#flash')
      expect(page).to have_content 'Proposal was successfully withdrawn.'
      @event.reload
      expect(@event.state).to eq('withdrawn')
    end

    it 'can reset to text template', feature: true, js: true do
      event_type = conference.program.event_types[-1]
      event_type.description = 'Example event description'
      event_type.submission_instructions = '## Fill Me In!'
      event_type.save!

      sign_in participant
      visit new_conference_program_proposal_path(conference.short_title)

      fill_in 'event_title', with: 'Example Proposal'
      select(event_type.title, from: 'event[event_type_id]')
      fill_in 'event_submission_text', with: 'Lorem ipsum example submission text'

      # accept_confirm do
      #   click_button 'Reset Submission to Template'
      # end

      # expect(page.find('#event_submission_text').value).to eq(event_type.submission_instructions)
    end
  end

  context 'as a user, looking at a conference with scheduled events' do
    before do
      @program = conference.program
      @selected_schedule = create(:schedule, program: @program)
      @program.update!(selected_schedule: @selected_schedule)
      @scheduled_event1 = create(:event, program: @program, state: 'confirmed', abstract: '`markdown`')
      @event_schedule1 = create(:event_schedule, event: @scheduled_event1, schedule: @selected_schedule,
start_time: conference.start_hour + 1.hour)
      @registration = conference.register_user(participant)
    end

    it 'for a scheduled event, can add an event to google calendar if signed in', feature: true do
      sign_in participant
      visit conference_program_proposal_path(conference.short_title, @scheduled_event1.id)
      expect(page).to have_content('Google Calendar')
    end

    it 'for a scheduled event, cannot add an event to google calendar if not signed on', feature: true do
      visit conference_program_proposal_path(conference.short_title, @scheduled_event1.id)
      expect(page).not_to have_content('Google Calendar')
    end

    context 'for events where you join the room via a link', feature: true do
      before do
        sign_in participant
      end

      # TODO-SNAPCON: Add test for unregistered user...
      it 'redirects to the event page with no URL' do
        visit join_conference_program_proposal_path(conference, @scheduled_event1)
        expect(page).to have_current_path conference_program_proposal_path(conference, @scheduled_event1),
                                          ignore_query: true
      end

      context 'with a fully setup event' do
        let(:venue) { create(:venue, conference: conference) }
        let(:room) { create(:room, venue: venue) }

        before do
          room.update(url: 'https://www.example.com')
          @event_schedule1.room = room
          @event_schedule1.save
        end

        xit 'redirects you to the room if you are registered' do
          visit join_conference_program_proposal_path(conference, @scheduled_event1)
          expect(current_url).to eq 'http://www.example.com'
        end

        it 'marks you as having attended the event and conference' do
          expect(@registration.attended).to be false
          expect(participant.attended_event?(@scheduled_event1)).to be false
          Timecop.travel @event_schedule1.start_time_in_conference_timezone - (Time.now.getlocal.utc_offset / 1.hours)
          # A check to make sure all conditions are met.
          expect(@scheduled_event1.happening_now?).to be true
          visit join_conference_program_proposal_path(conference, @scheduled_event1)
          @registration.reload
          expect(@registration.attended).to be true
          expect(participant.attended_event?(@scheduled_event1)).to be true
          Timecop.return
        end
      end
    end
  end

  context 'happening now or next section' do
    let!(:conference1) do
      create(:full_conference, start_date: 1.day.ago, end_date: 7.days.from_now, start_hour: 0, end_hour: 24)
    end
    let!(:program) { conference1.program }
    let!(:selected_schedule) { create(:schedule, program: program) }
    let!(:splashpage) { create(:full_splashpage, conference: conference1, public: true) }

    let!(:scheduled_event1) do
      program.update!(selected_schedule: selected_schedule)
      create(:event, program: program, state: 'confirmed')
    end
    let!(:scheduled_event2) do
      program.update!(selected_schedule: selected_schedule)
      create(:event, program: program, state: 'confirmed')
    end
    let!(:scheduled_event3) do
      program.update!(selected_schedule: selected_schedule)
      create(:event, program: program, state: 'confirmed')
    end
    let!(:scheduled_event4) do
      program.update!(selected_schedule: selected_schedule)
      create(:event, program: program, state: 'confirmed')
    end
    let!(:current_time) { Time.now.in_time_zone(conference1.timezone) }

    let!(:events_list) { [scheduled_event1, scheduled_event2, scheduled_event3, scheduled_event4] }

    before do
      sign_in participant
    end

    it 'No events happening now or next' do
      events_list.each do |event|
        visit conference_program_proposal_path(conference1.short_title, event.id)
        happening_now = page.find('#happening-now')
        expect(happening_now).to have_content('There are no upcoming events.')
      end
    end

    it 'shows all events happening next if nothing is happening now' do
      event_schedule1 = create(:event_schedule, event: scheduled_event1, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule2 = create(:event_schedule, event: scheduled_event2, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))

      events_list.each do |event|
        visit conference_program_proposal_path(conference1.short_title, event.id)
        happening_now = page.find('#happening-now')
        expect(happening_now).to have_content(event_schedule1.event.title)
        expect(happening_now).to have_content(event_schedule2.event.title)
        expect(happening_now).not_to have_content(scheduled_event3.title)
        expect(happening_now).not_to have_content(scheduled_event4.title)
      end
    end

    it 'only shows all events happening now if something is happening now and next' do
      event_schedule1 = create(:event_schedule, event: scheduled_event1, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule2 = create(:event_schedule, event: scheduled_event2, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule3 = create(:event_schedule, event: scheduled_event3, schedule: selected_schedule,
start_time: current_time.strftime('%a, %d %b %Y %H:%M:%S'))
      events_list.each do |event|
        visit conference_program_proposal_path(conference1.short_title, event.id)
        happening_now = page.find('#happening-now')
        expect(happening_now).not_to have_content(event_schedule1.event.title)
        expect(happening_now).not_to have_content(event_schedule2.event.title)
        expect(happening_now).to have_content(event_schedule3.event.title)
        expect(happening_now).not_to have_content(scheduled_event4.title)
      end
    end

    it 'only shows events happening at the earliest time, not at a later time in the future' do
      event_schedule1 = create(:event_schedule, event: scheduled_event1, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule2 = create(:event_schedule, event: scheduled_event2, schedule: selected_schedule,
start_time: (current_time + 1.hour).strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule3 = create(:event_schedule, event: scheduled_event3, schedule: selected_schedule,
start_time: (current_time + 2.hours).strftime('%a, %d %b %Y %H:%M:%S'))
      events_list.each do |event|
        visit conference_program_proposal_path(conference1.short_title, event.id)
        happening_now = page.find('#happening-now')
        expect(happening_now).to have_content(event_schedule1.event.title)
        expect(happening_now).to have_content(event_schedule2.event.title)
        expect(happening_now).not_to have_content(event_schedule3.event.title)
        expect(happening_now).not_to have_content(scheduled_event4.title)
      end
    end

    it 'only shows 3 events happening now because of pagination' do
      event_schedule1 = create(:event_schedule, event: scheduled_event1, schedule: selected_schedule,
start_time: current_time.strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule2 = create(:event_schedule, event: scheduled_event2, schedule: selected_schedule,
start_time: current_time.strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule3 = create(:event_schedule, event: scheduled_event3, schedule: selected_schedule,
start_time: current_time.strftime('%a, %d %b %Y %H:%M:%S'))
      event_schedule4 = create(:event_schedule, event: scheduled_event4, schedule: selected_schedule,
start_time: current_time.strftime('%a, %d %b %Y %H:%M:%S'))

      events_list.each do |event|
        visit conference_program_proposal_path(conference1.short_title, event.id)
        happening_now = page.find('#happening-now')
        expect(happening_now).to have_content(event_schedule1.event.title)
        expect(happening_now).to have_content(event_schedule2.event.title)
        expect(happening_now).to have_content(event_schedule3.event.title)

        visit conference_program_proposal_path(conference1.short_title, event.id, page: 2)
        happening_now = page.find('#happening-now')
        expect(happening_now).not_to have_content(event_schedule3.event.title)
        expect(happening_now).not_to have_content(event_schedule1.event.title)
        expect(happening_now).not_to have_content(event_schedule2.event.title)
        expect(happening_now).to have_content(event_schedule4.event.title)
      end
    end
  end
end
