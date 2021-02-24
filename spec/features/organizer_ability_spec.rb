# frozen_string_literal: true

require 'spec_helper'

feature 'Has correct abilities' do

  let(:organization) { create(:organization) }
  let(:conference) { create(:full_conference, organization: organization) }
  let(:other_conference) { create(:conference, organization: organization) } # user is organizer, venue is not set by default
  let(:role_organizer_conf) { Role.find_by(name: 'organizer', resource: conference) }
  let(:role_organizer_other_conf) { Role.find_by(name: 'organizer', resource: other_conference) }
  let(:user_organizer) { create(:user, role_ids: [role_organizer_conf.id, role_organizer_other_conf.id]) }
  let!(:registration_ticket) { create(:registration_ticket, conference: conference) }

  context 'when user is organizer' do
    before do
      sign_in user_organizer
    end

    scenario 'for organization attributes' do
      visit admin_organizations_path
      expect(current_path).to eq(admin_organizations_path)

      visit edit_admin_organization_path(organization)
      expect(current_path).to eq(root_path)

      visit new_admin_organization_path
      expect(current_path).to eq(root_path)
    end

    scenario 'for conference attributes' do
      visit admin_conference_path(conference.short_title)
      expect(current_path).to eq(admin_conference_path(conference.short_title))

      expect(page).to have_selector('li.nav-header.nav-header-bigger a', text: 'Dashboard')
      expect(page).to have_link('Basics', href: "/admin/conferences/#{conference.short_title}/edit")
      expect(page).to have_link('Contact', href: "/admin/conferences/#{conference.short_title}/contact/edit")
      expect(page).to have_link('Materials', href: "/admin/conferences/#{conference.short_title}/commercials")
      expect(page).to have_link('Splashpage', href: "/admin/conferences/#{conference.short_title}/splashpage")
      expect(page).to have_link('Venue', href: "/admin/conferences/#{conference.short_title}/venue")
      expect(page).to have_link('Rooms', href: "/admin/conferences/#{conference.short_title}/venue/rooms")
      expect(page).to have_link('Lodgings', href: "/admin/conferences/#{conference.short_title}/lodgings")
      expect(page).to have_link('Program', href: "/admin/conferences/#{conference.short_title}/program")
      expect(page).to have_link('Calls for Content', href: "/admin/conferences/#{conference.short_title}/program/cfps")
      expect(page).to have_link('Events', href: "/admin/conferences/#{conference.short_title}/program/events")
      expect(page).to have_link('Tracks', href: "/admin/conferences/#{conference.short_title}/program/tracks")
      expect(page).to have_link('Event Types', href: "/admin/conferences/#{conference.short_title}/program/event_types")
      expect(page).to have_link('Difficulty Levels', href: "/admin/conferences/#{conference.short_title}/program/difficulty_levels")
      expect(page).to have_link('Schedules', href: "/admin/conferences/#{conference.short_title}/schedules")
      expect(page).to have_link('Reports', href: "/admin/conferences/#{conference.short_title}/program/reports")
      expect(page).to have_link('Registrations', href: "/admin/conferences/#{conference.short_title}/registrations")
      expect(page).to have_link('Registration Period', href: "/admin/conferences/#{conference.short_title}/registration_period")
      expect(page).to have_link('Questions', href: "/admin/conferences/#{conference.short_title}/questions")
      expect(page).to have_text('Donations')
      expect(page).to have_link('Sponsorship Levels', href: "/admin/conferences/#{conference.short_title}/sponsorship_levels")
      expect(page).to have_link('Sponsors', href: "/admin/conferences/#{conference.short_title}/sponsors")
      expect(page).to have_link('Tickets', href: "/admin/conferences/#{conference.short_title}/tickets")
      expect(page).to have_link('E-Mails', href: "/admin/conferences/#{conference.short_title}/emails")
      expect(page).to have_link('Roles', href: "/admin/conferences/#{conference.short_title}/roles")
      expect(page).to have_link('Resources', href: "/admin/conferences/#{conference.short_title}/resources")
      expect(page).to_not have_link('New Conference', href: '/admin/conferences/new')

      visit admin_conference_path(other_conference.short_title)
      # TODO-SNAPCON: This conference already seems to have a venue.
      # expect(page).to have_link('Add venue', href: "/admin/conferences/#{other_conference.short_title}/venue/new")

      visit edit_admin_conference_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_path(conference.short_title))

      visit edit_admin_conference_contact_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_contact_path(conference.short_title))

      visit admin_conference_commercials_path(conference.short_title)
      expect(current_path).to eq(admin_conference_commercials_path(conference.short_title))

      visit new_admin_conference_splashpage_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_splashpage_path(conference.short_title))

      visit edit_admin_conference_splashpage_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_splashpage_path(conference.short_title))

      visit new_admin_conference_venue_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_venue_path(conference.short_title))

      conference.venue = create(:venue)
      visit edit_admin_conference_venue_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_venue_path(conference.short_title))

      visit admin_conference_venue_rooms_path(conference.short_title)
      expect(current_path).to eq(admin_conference_venue_rooms_path(conference.short_title))

      create(:room, venue: conference.venue)
      visit edit_admin_conference_venue_room_path(conference.short_title, conference.venue.rooms.first)
      expect(current_path).to eq(edit_admin_conference_venue_room_path(conference.short_title, conference.venue.rooms.first))

      visit admin_conference_lodgings_path(conference.short_title)
      expect(current_path).to eq(admin_conference_lodgings_path(conference.short_title))

      visit new_admin_conference_lodging_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_lodging_path(conference.short_title))

      create(:lodging, conference: conference)
      visit edit_admin_conference_lodging_path(conference.short_title, conference.lodgings.first)
      expect(current_path).to eq(edit_admin_conference_lodging_path(conference.short_title, conference.lodgings.first))

      visit new_admin_conference_program_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_path(conference.short_title))

      visit edit_admin_conference_program_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_program_path(conference.short_title))

      # Only event type exists
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_cfp_path(conference.short_title))

      # Event and booth cfps exist
      cfb = create(:cfp, cfp_type: 'booths', program: conference.program)
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq new_admin_conference_program_cfp_path(conference.short_title)

      visit edit_admin_conference_program_cfp_path(conference.short_title, conference.program.cfp)
      expect(current_path).to eq(edit_admin_conference_program_cfp_path(conference.short_title, conference.program.cfp))

      # Event, booth, track cfps exist
      call_for_tracks = create(:cfp, cfp_type: 'tracks', program: conference.program)
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq root_path

      # Booth and track cfps exist
      conference.program.cfp.destroy!
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq new_admin_conference_program_cfp_path(conference.short_title)

      # Only booth exists
      call_for_tracks.destroy!
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_cfp_path(conference.short_title))

      visit edit_admin_conference_program_cfp_path(conference.short_title, cfb)
      expect(current_path). to eq(edit_admin_conference_program_cfp_path(conference.short_title, cfb))

      # No cfp exists
      cfb.destroy
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_cfp_path(conference.short_title))

      # Only Tracks cfp exists
      call_for_tracks = create(:cfp, cfp_type: 'tracks', program: conference.program)
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq new_admin_conference_program_cfp_path(conference.short_title)

      visit edit_admin_conference_program_cfp_path(conference.short_title, call_for_tracks)
      expect(current_path).to eq edit_admin_conference_program_cfp_path(conference.short_title, call_for_tracks)

      # Event and track cfps exist
      create(:cfp, cfp_type: 'events', program: conference.program)
      visit new_admin_conference_program_cfp_path(conference.short_title)
      expect(current_path).to eq new_admin_conference_program_cfp_path(conference.short_title)

      call_for_tracks.destroy!
      visit admin_conference_program_events_path(conference.short_title)
      expect(current_path).to eq(admin_conference_program_events_path(conference.short_title))

      create(:event, program: conference.program)
      visit edit_admin_conference_program_event_path(conference.short_title, conference.program.events.first)
      expect(current_path).to eq(edit_admin_conference_program_event_path(conference.short_title, conference.program.events.first))

      visit admin_conference_program_event_types_path(conference.short_title)
      expect(current_path).to eq(admin_conference_program_event_types_path(conference.short_title))

      visit new_admin_conference_program_event_type_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_event_type_path(conference.short_title))

      visit edit_admin_conference_program_event_type_path(conference.short_title, conference.program.event_types.first)
      expect(current_path).to eq(edit_admin_conference_program_event_type_path(conference.short_title, conference.program.event_types.first))

      visit admin_conference_program_difficulty_levels_path(conference.short_title)
      expect(current_path).to eq(admin_conference_program_difficulty_levels_path(conference.short_title))

      visit new_admin_conference_program_difficulty_level_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_program_difficulty_level_path(conference.short_title))

      visit edit_admin_conference_program_difficulty_level_path(conference.short_title, conference.program.difficulty_levels.first)
      expect(current_path).to eq(edit_admin_conference_program_difficulty_level_path(conference.short_title, conference.program.difficulty_levels.first))

      visit admin_conference_schedules_path(conference.short_title)
      expect(current_path).to eq(admin_conference_schedules_path(conference.short_title))

      create(:schedule, program: conference.program)
      visit admin_conference_schedule_path(conference.short_title, conference.program.schedules.first)
      expect(current_path).to eq(admin_conference_schedule_path(conference.short_title, conference.program.schedules.first))

      visit admin_conference_program_reports_path(conference.short_title)
      expect(current_path).to eq(admin_conference_program_reports_path(conference.short_title))

      visit admin_conference_registrations_path(conference.short_title)
      expect(current_path).to eq(admin_conference_registrations_path(conference.short_title))

      # Create a registration for a user, which requires a registration ticket.
      other_user = create(:user)
      ticket = conference.registration_tickets.first
      create(:paid_ticket_purchase,
        user: other_user, ticket: ticket, quantity: 1, conference: conference)
      create(:registration, user: other_user, conference: conference)
      visit edit_admin_conference_registration_path(conference.short_title, conference.registrations.first)
      expect(current_path).to eq(edit_admin_conference_registration_path(conference.short_title, conference.registrations.first))

      visit new_admin_conference_registration_period_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_registration_period_path(conference.short_title))

      create(:registration_period, conference: conference)
      visit edit_admin_conference_registration_period_path(conference.short_title)
      expect(current_path).to eq(edit_admin_conference_registration_period_path(conference.short_title))

      visit admin_conference_questions_path(conference.short_title)
      expect(current_path).to eq(admin_conference_questions_path(conference.short_title))

      visit admin_conference_sponsorship_levels_path(conference.short_title)
      expect(current_path).to eq(admin_conference_sponsorship_levels_path(conference.short_title))

      visit new_admin_conference_sponsorship_level_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_sponsorship_level_path(conference.short_title))

      create(:sponsorship_level, conference: conference)
      visit edit_admin_conference_sponsorship_level_path(conference.short_title, conference.sponsorship_levels.first)
      expect(current_path).to eq(edit_admin_conference_sponsorship_level_path(conference.short_title, conference.sponsorship_levels.first))

      visit admin_conference_sponsors_path(conference.short_title)
      expect(current_path).to eq(admin_conference_sponsors_path(conference.short_title))

      visit new_admin_conference_sponsor_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_sponsor_path(conference.short_title))

      create(:sponsor, conference: conference, sponsorship_level: conference.sponsorship_levels.first)
      visit edit_admin_conference_sponsor_path(conference.short_title, conference.sponsors.first)
      expect(current_path).to eq(edit_admin_conference_sponsor_path(conference.short_title, conference.sponsors.first))

      visit admin_conference_tickets_path(conference.short_title)
      expect(current_path).to eq(admin_conference_tickets_path(conference.short_title))

      visit new_admin_conference_ticket_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_ticket_path(conference.short_title))

      create(:ticket, conference: conference)
      visit edit_admin_conference_ticket_path(conference.short_title, conference.tickets.first)
      expect(current_path).to eq(edit_admin_conference_ticket_path(conference.short_title, conference.tickets.first))

      visit admin_conference_booths_path(conference.short_title)
      expect(current_path).to eq(admin_conference_booths_path(conference.short_title))

      visit new_admin_conference_booth_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_booth_path(conference.short_title))

      create(:booth, conference: conference)
      visit edit_admin_conference_booth_path(conference.short_title, conference.booths.first)
      expect(current_path).to eq(edit_admin_conference_booth_path(conference.short_title, conference.booths.first))

      visit admin_conference_program_tracks_path(conference.short_title)
      expect(current_path).to eq(admin_conference_program_tracks_path(conference.short_title))

      visit admin_conference_roles_path(conference.short_title)
      expect(current_path).to eq(admin_conference_roles_path(conference.short_title))

      visit admin_conference_emails_path(conference.short_title)
      expect(current_path).to eq(admin_conference_emails_path(conference.short_title))

      visit admin_conference_resources_path(conference.short_title)
      expect(current_path).to eq(admin_conference_resources_path(conference.short_title))

      visit new_admin_conference_resource_path(conference.short_title)
      expect(current_path).to eq(new_admin_conference_resource_path(conference.short_title))

      create(:resource, conference: conference)
      visit edit_admin_conference_resource_path(conference.short_title, conference.resources.first)
      expect(current_path).to eq(edit_admin_conference_resource_path(conference.short_title, conference.resources.first))

      visit admin_users_path
      expect(current_path).to eq(root_path)

      visit admin_user_path(user_organizer)
      expect(current_path).to eq(root_path)

      visit admin_revision_history_path
      expect(current_path).to eq(admin_revision_history_path)
    end
  end
end
