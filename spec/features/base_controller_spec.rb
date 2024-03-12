# frozen_string_literal: true

require 'spec_helper'

describe 'BaseController' do
  let(:conference) { create(:conference) }
  let(:user) { create(:user) }

  let!(:organizer_role) { Role.find_by(name: 'organizer', resource: conference) }
  let!(:volunteers_coordinator_role) { Role.find_by(name: 'volunteers_coordinator', resource: conference) }
  let!(:cfp_role) { Role.find_by(name: 'cfp', resource: conference) }
  let!(:info_desk_role) { Role.find_by(name: 'info_desk', resource: conference) }

  describe 'GET #verify_user_admin' do
    context 'when user is a guest' do
      before do
        sign_out
      end

      it 'redirects to sign in page' do
        visit admin_conferences_path
        expect(page).to have_current_path new_user_session_path, ignore_query: true
      end
    end

    context 'when user is' do
      before do
        sign_in(user)
      end

      it 'not an admin it redirects to root_path' do
        visit admin_conferences_path
        expect(page).to have_current_path root_path, ignore_query: true
        expect(flash).to eq 'You are not authorized to access this page.'
      end

      it 'an admin they can access the admin area' do
        user.is_admin = true
        visit admin_conferences_path
        expect(page).to have_current_path admin_conferences_path, ignore_query: true
      end

      it 'an organizer they can access the admin area' do
        user.role_ids = organizer_role.id
        visit admin_conferences_path
        expect(page).to have_current_path admin_conferences_path, ignore_query: true
      end

      it 'a volunteers_coordinator they can access the admin area' do
        user.role_ids = volunteers_coordinator_role.id
        visit admin_conferences_path
        expect(page).to have_current_path admin_conferences_path, ignore_query: true
      end

      it 'a cfp they can access the admin area' do
        user.role_ids = cfp_role.id
        visit admin_conferences_path
        expect(page).to have_current_path admin_conferences_path, ignore_query: true
      end

      it 'an info_desk they can access the admin area' do
        user.role_ids = info_desk_role.id
        visit admin_conferences_path
        expect(page).to have_current_path admin_conferences_path, ignore_query: true
      end
    end
  end
end
