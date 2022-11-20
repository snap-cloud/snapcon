# frozen_string_literal: true

require 'spec_helper'
require 'cancan/matchers'

describe 'User' do
  describe 'Abilities' do
    # see https://github.com/CanCanCommunity/cancancan/wiki/Testing-Abilities
    subject(:ability) { Ability.new(user) }

    let!(:admin) { create(:admin) }

    let(:user) { nil }

    let!(:organization) { create(:organization) }
    let!(:my_conference) { create(:full_conference, organization:) }

    let(:my_room) { create(:room, venue: my_conference.venue) }

    let(:conference_not_public) { create(:conference, splashpage: create(:splashpage, public: false)) }
    let(:conference_public) { create(:full_conference, splashpage: create(:splashpage, public: true)) }

    let(:event_confirmed) { create(:event, state: 'confirmed') }
    let(:event_unconfirmed) { create(:event) }

    let(:commercial_event_confirmed) { create(:commercial, commercialable: event_confirmed) }
    let(:commercial_event_unconfirmed) { create(:commercial, commercialable: event_unconfirmed) }
    let(:registration) { create(:registration) }

    let(:program_with_cfp) { create(:program, :with_cfp) }
    let(:program_without_cfp) { create(:program) }
    let(:program_with_call_for_tracks) { create(:cfp, cfp_type: 'tracks').program }
    let(:conference_with_open_registration) { create(:conference) }
    let!(:open_registration_period) do
      create(:registration_period, conference: conference_with_open_registration, start_date: Date.current - 6.days)
    end
    let(:conference_with_closed_registration) { create(:conference) }
    let!(:closed_registration_period) do
      create(:registration_period, conference: conference_with_closed_registration, start_date: Date.current - 6.days,
     end_date: Date.current - 6.days)
    end

    # Test abilities for not signed in users
    context 'when user is not signed in' do
      it { is_expected.to be_able_to(:index, Organization) }
      it { is_expected.to be_able_to(:index, Conference) }

      it { is_expected.to be_able_to(:show, conference_public) }
      it { is_expected.not_to be_able_to(:show, conference_not_public) }

      it do
        conference_public.program.schedule_public = true
        conference_public.program.save
        expect(subject).to be_able_to(:schedule, conference_public)
      end

      it { is_expected.not_to be_able_to(:schedule, conference_not_public) }

      it { is_expected.to be_able_to(:show, event_confirmed) }
      it { is_expected.not_to be_able_to(:show, event_unconfirmed) }

      it { is_expected.to be_able_to(:show, commercial_event_confirmed) }
      it { is_expected.not_to be_able_to(:show, commercial_event_unconfirmed) }

      it { is_expected.to be_able_to(:show, User) }
      it { is_expected.to be_able_to(:create, User) }

      it { is_expected.to be_able_to(:show, Registration.new) }
      it { is_expected.to be_able_to(:create, Registration.new(conference_id: conference_with_open_registration.id)) }
      it { is_expected.to be_able_to(:new, Registration.new(conference_id: conference_with_open_registration.id)) }

      it {
        expect(subject).not_to be_able_to(:new, Registration.new(conference_id: conference_with_closed_registration.id))
      }

      it {
        expect(subject).not_to be_able_to(:create,
                                          Registration.new(conference_id: conference_with_closed_registration.id))
      }

      it { is_expected.not_to be_able_to(:manage, registration) }

      it { is_expected.to be_able_to(:new, Event.new(program: program_with_cfp)) }
      it { is_expected.not_to be_able_to(:new, Event.new(program: program_without_cfp)) }
      it { is_expected.not_to be_able_to(:create, Event.new(program: program_without_cfp)) }
      it { is_expected.to be_able_to(:show, Event.new) }

      it { is_expected.not_to be_able_to(:manage, :any) }
    end

    # Test abilities for signed in users (without any role)
    context 'when user is signed in' do
      let(:user) { create(:user) }
      let(:user2) { create(:user) }
      let(:event_user2) { create(:submitter, user: user2) }

      let(:subscription) { create(:subscription, user:) }
      let(:registration_public) { create(:registration, conference: conference_public, user:) }
      let(:registration_not_public) { create(:registration, conference: conference_not_public, user:) }

      let(:user_event_with_cfp) { create(:event, users: [user], program: program_with_cfp) }
      let(:user_commercial) { create(:commercial, commercialable: user_event_with_cfp) }
      let(:user_self_organized_track) { create(:track, :self_organized, submitter: user) }
      let(:accepted_user_self_organized_track) { create(:track, :self_organized, submitter: user, state: 'accepted') }
      let(:confirmed_user_self_organized_track) { create(:track, :self_organized, submitter: user, state: 'confirmed') }
      let(:other_self_organized_track) { create(:track, :self_organized) }

      it { is_expected.to be_able_to(:manage, user) }
      it { is_expected.to be_able_to(:manage, registration_public) }
      it { is_expected.to be_able_to(:manage, registration_not_public) }

      # Test for user can register or not
      context 'when user is not a speaker with event confirmed' do
        let(:conference) { create(:conference) }

        context 'when the registration is closed' do
          before do
            create(:registration_period, conference:, start_date: Date.current - 6.days,
end_date: Date.current - 6.days)
          end

          it { is_expected.not_to be_able_to(:new, Registration.new(conference:)) }
          it { is_expected.not_to be_able_to(:create, Registration.new(conference:)) }
        end

        context 'when the registration period is not set' do
          it { is_expected.not_to be_able_to(:new, Registration.new(conference:)) }
          it { is_expected.not_to be_able_to(:create, Registration.new(conference:)) }
        end

        context 'when user has already registered' do
          before do
            create(:registration, conference:, user:)
          end

          it { is_expected.not_to be_able_to(:new, Registration.new(conference:)) }
          it { is_expected.not_to be_able_to(:create, Registration.new(conference:)) }
        end

        context 'when registrations are open' do
          before do
            create(:registration_period, conference:)
          end

          it { is_expected.to be_able_to(:new, Registration.new(conference:)) }
          it { is_expected.to be_able_to(:create, Registration.new(conference:)) }

          context 'when user has not registered with no registration_limit_exceeded' do
            before do
              conference.registration_limit = 1
            end

            it { is_expected.to be_able_to(:new, Registration.new(conference:)) }
            it { is_expected.to be_able_to(:create, Registration.new(conference:)) }
          end

          context 'when user has not registered with registration_limit_exceeded' do
            before do
              conference.registration_limit = 1
              create(:registration, conference:, user: user2)
            end

            it { is_expected.not_to be_able_to(:new, Registration.new(conference:)) }
            it { is_expected.not_to be_able_to(:create, Registration.new(conference:)) }
          end
        end
      end

      context 'when user is a speaker with event confirmed' do
        let(:conference_with_speaker_confirmed) { create(:conference) }
        let(:event_with_speaker_confirmed) do
          create(:event, state: 'confirmed', program: conference_with_speaker_confirmed.program)
        end

        before do
          event_with_speaker_confirmed.speakers << user
        end

        context 'when registration period is not set' do
          it { is_expected.not_to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
          it { is_expected.not_to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
        end

        context 'when speaker has already registered' do
          before do
            create(:registration, conference: conference_with_speaker_confirmed, user:)
          end

          it { is_expected.not_to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
          it { is_expected.not_to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
        end

        context 'when registration period is set' do
          before do
            create(:registration_period, conference: conference_with_speaker_confirmed)
          end

          context 'when registrations are open' do
            context 'when speaker has not registered' do
              it { is_expected.to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
              it { is_expected.to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
            end

            context 'when registration_limit_exceeded' do
              before do
                conference_with_speaker_confirmed.registration_limit = 1
                create(:registration, conference: conference_with_speaker_confirmed, user: user2)
              end

              it { is_expected.to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
              it { is_expected.to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
            end
          end

          context 'when registrations are closed' do
            before do
              create(:registration_period, conference: conference_with_speaker_confirmed,
start_date: Date.current - 6.days, end_date: Date.current - 6.days)
            end

            context 'when speaker has not registered' do
              it { is_expected.to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
              it { is_expected.to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
            end

            context 'with registration_limit_exceeded' do
              before do
                conference_with_speaker_confirmed.registration_limit = 1
                create(:registration, conference: conference_with_speaker_confirmed, user: user2)
              end

              it { is_expected.to be_able_to(:new, Registration.new(conference: conference_with_speaker_confirmed)) }
              it { is_expected.to be_able_to(:create, Registration.new(conference: conference_with_speaker_confirmed)) }
            end
          end
        end
      end

      it { is_expected.to be_able_to(:index, Ticket) }
      it { is_expected.to be_able_to(:manage, TicketPurchase.new(user_id: user.id)) }

      it { is_expected.to be_able_to(:new, Payment.new(user_id: user.id)) }
      it { is_expected.to be_able_to(:create, Payment.new(user_id: user.id)) }

      it { is_expected.to be_able_to(:create, Subscription.new(user_id: user.id)) }
      it { is_expected.to be_able_to(:destroy, subscription) }

      it { is_expected.to be_able_to(:update, user_event_with_cfp) }
      it { is_expected.to be_able_to(:show, user_event_with_cfp) }
      it { is_expected.not_to be_able_to(:new, Event.new(program: program_without_cfp)) }
      it { is_expected.not_to be_able_to(:create, Event.new(program: program_without_cfp)) }

      # TODO: At moment it's not possible to manually add someone else as event_user
      # This needs some more work once we allow user to add event_user
      it 'should_not be_able to :new, Event.new(program: program_with_cfp, event_users: [event_user2])'
      it 'should_not be_able to :create, Event.new(program: program_with_cfp, event_users: [event_user2])'

      it { is_expected.not_to be_able_to(:manage, event_unconfirmed) }

      it { is_expected.to be_able_to(:create, user_event_with_cfp.commercials.new) }
      it { is_expected.to be_able_to(:manage, user_commercial) }
      it { is_expected.not_to be_able_to(:manage, commercial_event_unconfirmed) }

      it { is_expected.to be_able_to(:new, Track.new(program: program_with_call_for_tracks)) }
      it { is_expected.to be_able_to(:create, Track.new(program: program_with_call_for_tracks)) }
      it { is_expected.not_to be_able_to(:new, Track.new(program: program_without_cfp)) }
      it { is_expected.not_to be_able_to(:create, Track.new(program: program_without_cfp)) }

      it { is_expected.to be_able_to(:index, user_self_organized_track) }
      it { is_expected.to be_able_to(:show, user_self_organized_track) }
      it { is_expected.to be_able_to(:restart, user_self_organized_track) }
      it { is_expected.to be_able_to(:confirm, user_self_organized_track) }
      it { is_expected.to be_able_to(:withdraw, user_self_organized_track) }
      it { is_expected.not_to be_able_to(:index, other_self_organized_track) }
      it { is_expected.not_to be_able_to(:show, other_self_organized_track) }
      it { is_expected.not_to be_able_to(:restart, other_self_organized_track) }
      it { is_expected.not_to be_able_to(:confirm, other_self_organized_track) }
      it { is_expected.not_to be_able_to(:withdraw, other_self_organized_track) }

      it { is_expected.to be_able_to(:edit, user_self_organized_track) }
      it { is_expected.to be_able_to(:update, user_self_organized_track) }
      it { is_expected.not_to be_able_to(:edit, accepted_user_self_organized_track) }
      it { is_expected.not_to be_able_to(:update, accepted_user_self_organized_track) }
      it { is_expected.not_to be_able_to(:edit, confirmed_user_self_organized_track) }
      it { is_expected.not_to be_able_to(:update, confirmed_user_self_organized_track) }
      it { is_expected.not_to be_able_to(:edit, other_self_organized_track) }
      it { is_expected.not_to be_able_to(:update, other_self_organized_track) }
    end
  end
end
