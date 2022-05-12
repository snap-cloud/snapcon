# frozen_string_literal: true

class RoomsController < ApplicationController
  include ConferenceHelper
  before_action :authenticate_user!
  protect_from_forgery with: :null_session
  load_resource :conference, find_by: :short_title

  # TODO: This duplicates too much of the #join route.
  def live_session
    @room = Room.find(params[:room_id])
    user_registered = @conference.user_registered?(current_user)
    can_view = user_registered || current_user.roles.where(id: @conference.roles).any?

    if true || @room.url.present? && can_view
      current_user.mark_attendance_for_conference(@conference)
    else
      redirect_to conference_schedule_path(@conference),
                  error: 'You cannot join this room yet. Please try again closer to the start of the event.'
    end
  end
end
