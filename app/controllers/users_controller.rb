# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!, only: :search
  load_and_authorize_resource

  # GET /users/1
  def show
    @events = @user.events.where(state: :confirmed)
  end

  # GET /users/1/edit
  def edit; end

  # PATCH/PUT /users/1
  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: 'User was successfully updated.'
    else
      flash.now[:error] = "An error prohibited your profile from being saved: #{@user.errors.full_messages.join('. ')}."
      render :edit
    end
  end

  def search
    fields = %i[username id name]
    fields << :email if current_user.is_admin?
    respond_to do |format|
      format.json do
        render json: { users:
                              User.active.where(
                                'username ILIKE :search OR email ILIKE :search OR name ILIKE :search',
                                search: "%#{params[:query]}%"
                              ).as_json(only: fields, methods: :dropdwon_display) }
      end
    end
  end

  private

  def user_params
    params[:user][:timezone] = params[:user][:timezone].presence || nil
    params.require(:user).permit(:name, :biography, :nickname, :affiliation,
                                 :picture, :picture_cache, :timezone)
  end

  # Somewhat of a hack: users/current/edit
  # rubocop:disable Naming/MemoizedInstanceVariableName
  def load_user
    @user ||= (params[:id] && params[:id] != 'current' && User.find(params[:id])) || current_user
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName
end
