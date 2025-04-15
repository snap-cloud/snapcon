# frozen_string_literal: true

require 'spec_helper'

describe ConferenceRegistrationsController, type: :controller do
  let(:conference) { create(:conference, title: 'My Conference', short_title: 'myconf') }
  let(:user) { create(:user) }
  let(:not_registered_user) { create(:user) }
  let(:registered_user) { create(:user) }
  let!(:registration) { create(:registration, conference: conference, user: registered_user, created_at: 1.day.ago) }

  shared_examples 'access #new action' do |user, ichain, path, message|
    before do
      sign_in send(user) if user
      ENV['OSEM_ICHAIN_ENABLED'] = ichain
      get :new, params: { conference_id: conference.short_title }
    end

    it 'redirects' do
      expect(response).to redirect_to path
    end

    it 'shows flash alert' do
      expect(flash[:alert]).to eq message
    end
  end

  shared_examples 'can access #new action' do |user, ichain|
    before do
      sign_in send(user) if user
      ENV['OSEM_ICHAIN_ENABLED'] = ichain
      get :new, params: { conference_id: conference.short_title }
    end

    it 'user variable exists' do
      expect(assigns(:user)).not_to be_nil
    end

    it 'renders the new template' do
      expect(response).to render_template('new')
    end
  end

  context 'user is signed in' do
    before do
      sign_in user
    end

    describe 'GET #new' do
      let(:not_registered_confirmed_speaker) { create(:user) }
      let(:registered_confirmed_speaker) { create(:user) }
      let!(:speaker_registration) do
        create(:registration, conference: conference, user: registered_confirmed_speaker, created_at: 1.day.ago)
      end
      let!(:confirmed_event) do
        create(:event, program: conference.program,
       speakers: [not_registered_confirmed_speaker, registered_confirmed_speaker], state: 'confirmed')
      end

      context 'registration period open' do
        before do
          create(:registration_period, conference: conference, start_date: 3.days.ago, end_date: 1.day.from_now)
        end

        context 'registration limit not exceeded' do
          before do
            conference.registration_limit = 0
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'true', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered' do
            it_behaves_like 'can access #new action', :not_registered_user, 'true'
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'true',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'true'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'false', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered' do
            it_behaves_like 'can access #new action', :not_registered_user, 'false'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'false',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'false'
          end
        end

        context 'registration limit exceeded' do
          before do
            conference.registration_limit = 1
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'true', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'true',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'true'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'false', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'false',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'false'
          end
        end
      end

      context 'registration period not open' do
        before do
          create(:registration_period, conference: conference, start_date: 3.days.ago, end_date: 1.day.ago)
        end

        context 'registration limit not exceeded' do
          before do
            conference.registration_limit = 0
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'true', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'true',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'true'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'false', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'false',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'false'
          end
        end

        context 'registration limit exceeded' do
          before do
            conference.registration_limit = 1
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'true', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED true, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'true',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED true, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'true'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered' do
            it_behaves_like 'access #new action', :registered_user, 'false', '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered' do
            it_behaves_like 'access #new action', :not_registered_user, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED false, user registered, confirmed speaker' do
            it_behaves_like 'access #new action', :registered_confirmed_speaker, 'false',
                            '/conferences/myconf/register/edit', nil
          end

          context 'OSEM_ICHAIN_ENABLED false, user not registered, confirmed speaker' do
            it_behaves_like 'can access #new action', :not_registered_confirmed_speaker, 'false'
          end
        end
      end
    end

    describe 'GET #show' do
      before do
        @registration = create(:registration, conference: conference, user: user)
        @event_with_registration = create(:event, program: conference.program, require_registration: true,
max_attendees: 5, state: 'confirmed')
        @event_without_registration = create(:event, program: conference.program, require_registration: true,
max_attendees: 5, state: 'confirmed')
        @registration.events << @event_with_registration
      end

      context 'successful request' do
        before do
          get :show, params: { conference_id: conference.short_title }
        end

        it 'assigns variables' do
          expect(assigns(:conference)).to eq conference
          expect(assigns(:registration)).to eq @registration
        end

        it 'renders the show template' do
          expect(response).to render_template('show')
        end
      end

      context 'user has not purchased any ticket' do
        before do
          get :show, params: { conference_id: conference.short_title }
        end

        it 'assigns an empty array to tickets variables' do
          expect(assigns(:purchases)).to match_array []
        end
      end

      context 'when user has purchased tickets' do
        let!(:purchase) { create(:ticket_purchase, user: user, conference: conference, quantity: 2, amount_paid_cents: 10_000, currency: 'USD', paid: true, ticket_id: 1) }
        let!(:purchase_not_paid) { create(:ticket_purchase, user: user, conference: conference, quantity: 2, amount_paid_cents: 10_000, currency: 'USD') }
        let!(:purchase_diff_id) { create(:ticket_purchase, user: user, conference: conference, quantity: 1, amount_paid_cents: 10_000, currency: 'USD', paid: true, ticket_id: 2) }
        let!(:purchase_diff_curr) { create(:ticket_purchase, user: user, conference: conference, quantity: 1, amount_paid_cents: 10_000, currency: 'CAD', paid: true, ticket_id: 1) }

        before do
          sign_in user
          get :show, params: { conference_id: conference.short_title }
        end

        it 'assigns @purchases correctly' do
          expect(assigns(:purchases)).to contain_exactly(purchase, purchase_diff_id, purchase_diff_curr)
        end

        it 'assigns @total_price_per_ticket_per_currency correctly' do
          expect(assigns(:total_price_per_ticket_per_currency)).to eq({ [purchase.ticket_id, 'USD'] => Money.new(20_000, 'USD'), [purchase_diff_id.ticket_id, 'USD'] => Money.new(10_000, 'USD'), [purchase_diff_curr.ticket_id, 'CAD'] => Money.new(10_000, 'CAD') })
        end

        it 'assigns @total_quantity correctly' do
          expect(assigns(:total_quantity)).to eq({ [purchase.ticket_id, 'USD'] => 2, [purchase_diff_id.ticket_id, 'USD'] => 1, [purchase_diff_curr.ticket_id, 'CAD'] => 1 })
        end

        it 'assigns @total_price_per_currency correctly' do
          expect(assigns(:total_price_per_currency)).to eq({ 'USD' => Money.new(30_000, 'USD'), 'CAD' => Money.new(10_000, 'CAD') })
        end
      end
    end

    describe 'GET #edit' do
      before do
        @registration = create(:registration, conference: conference, user: user)
        get :edit, params: { conference_id: conference.short_title }
      end

      it 'assigns conference and registration variable' do
        expect(assigns(:conference)).to eq conference
        expect(assigns(:registration)).to eq @registration
      end

      it 'renders the edit template' do
        expect(response).to render_template('edit')
      end
    end

    describe 'PATCH #update' do
      before do
        @registration = create(:registration,
                               conference: conference,
                               user:       user)
      end

      context 'updates successfully' do
        before do
          patch :update, params: {
            registration:  attributes_for(:registration, volunteer: true),
            conference_id: conference.short_title
          }
        end

        it 'redirects to registration show path' do
          expect(response).to redirect_to conference_conference_registration_path(conference.short_title)
        end

        it 'shows success message in flash notice' do
          expect(flash[:notice]).to match('Registration was successfully updated.')
        end

        it 'updates the registration' do
          expect { @registration.reload }.to change(@registration, :updated_at)
        end
      end

      context 'update fails' do
        before do
          allow_any_instance_of(Registration).to receive(:update).and_return(false)
          patch :update, params: {
            registration:  attributes_for(:registration, volunteer: true),
            conference_id: conference.short_title
          }
        end

        it 'renders edit template' do
          expect(response).to render_template('edit')
        end

        it 'shows error in flash message' do
          expect(flash[:error]).to match "Could not update your registration for #{conference.title}: #{@registration.errors.full_messages.join('. ')}."
        end

        it 'does not update the registration' do
          @registration.reload
          expect { @registration.reload }.not_to change(@registration, :updated_at)
        end
      end
    end

    describe 'DELETE #destroy' do
      before do
        @registration = create(:registration, conference: conference, user: user)
      end

      context 'deletes successfully' do
        before(:each, run: true) do
          delete :destroy, params: { conference_id: conference.short_title }
        end

        it 'redirects to root path', run: true do
          expect(response).to redirect_to root_path
        end

        it 'shows success message in flash notice', run: true do
          expect(flash[:notice]).to match("You are not registered for #{conference.title} anymore!")
        end

        it 'deletes the registration' do
          expect do
            delete :destroy, params: { conference_id: conference.short_title }
          end.to change { Registration.count }.from(2).to(1)
        end
      end

      context 'delete fails' do
        before do
          allow_any_instance_of(Registration).to receive(:destroy).and_return(false)
          delete :destroy, params: { conference_id: conference.short_title }
        end

        it 'redirects to registration show path' do
          expect(response).to redirect_to conference_conference_registration_path(conference.short_title)
        end

        it 'shows error in flash message' do
          expect(flash[:error]).to match "Could not delete your registration for #{conference.title}: #{@registration.errors.full_messages.join('. ')}."
        end

        it 'does not delete the registration' do
          expect(assigns(:registration)).to eq @registration
        end
      end
    end
  end

  context 'user is not signed in' do
    describe 'GET #new' do
      context 'registration period open' do
        before do
          create(:registration_period, conference: conference, start_date: 3.days.ago, end_date: 1.day.from_now)
        end

        context 'registration limit not exceeded' do
          before do
            conference.registration_limit = 0
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED is true' do
            it_behaves_like 'access #new action', nil, 'true', '/',
                            'You are not authorized to access this page. Maybe you need to sign in?'
          end

          context 'OSEM_ICHAIN_ENABLED is false' do
            it_behaves_like 'can access #new action', nil, 'false'
          end
        end

        context 'registration limit exceeded' do
          before do
            conference.registration_limit = 1
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED is true' do
            it_behaves_like 'access #new action', nil, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED is false' do
            it_behaves_like 'access #new action', nil, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end
        end
      end

      context 'registration period not open' do
        before do
          create(:registration_period, conference: conference, start_date: 3.days.ago, end_date: 1.day.ago)
        end

        context 'registration limit not exceeded' do
          before do
            conference.registration_limit = 0
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED is true' do
            it_behaves_like 'access #new action', nil, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED is false' do
            it_behaves_like 'access #new action', nil, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end
        end

        context 'registration limit exceeded' do
          before do
            conference.registration_limit = 1
            conference.save!
          end

          context 'OSEM_ICHAIN_ENABLED is true' do
            it_behaves_like 'access #new action', nil, 'true', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end

          context 'OSEM_ICHAIN_ENABLED is false' do
            it_behaves_like 'access #new action', nil, 'false', '/',
                            'Sorry, you can not register for My Conference. Registration limit exceeded or the registration is not open.'
          end
        end
      end
    end
  end
end
