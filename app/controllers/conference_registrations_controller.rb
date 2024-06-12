# frozen_string_literal: true

class ConferenceRegistrationsController < ApplicationController
  before_action :authenticate_user!, except: %i[new create]
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration, except: %i[new create]
  before_action :set_registration, only: %i[edit update destroy show]

  def new
    @registration = Registration.new(conference_id: @conference.id)

    # Redirect to registration edit when user is already registered
    if @conference.user_registered?(current_user)
      # Authorization needs to happen in every action before the return statement
      # We authorize the #edit action, since we redirect to it
      authorize! :edit, current_user.registrations.find_by(conference_id: @conference.id)
      redirect_to edit_conference_conference_registration_path(@conference.short_title)
      return
    end

    if !@conference.registration_open? || @conference.registration_limit_exceeded?
      message = "Sorry, you can not register for #{@conference.title}. Registration limit exceeded or the registration is not open."
      @ignore_not_signed_in_user = true
    end
    authorize! :new, @registration, message: message

    # @user needs to be set for devise/registrations/new_embedded
    @user = @registration.build_user
  end

  def show
    @purchases = current_user.ticket_purchases.by_conference(@conference).paid
    summed_per_ticket_per_currency = @purchases.group(:ticket_id, :currency).sum('amount_paid_cents * quantity')
    @total_price_per_ticket_per_currency = summed_per_ticket_per_currency.each_with_object({}) do |((ticket_id, currency), amount), hash|
      hash[[ticket_id, currency]] = Money.new(amount, currency)
    end
    @total_quantity = @purchases.group(:ticket_id, :currency).sum(:quantity)
    sum_total_currency = @purchases.group(:currency).sum('amount_paid_cents * quantity')
    @total_price_per_currency = sum_total_currency.each_with_object({}) do |(currency, amount), hash|
      hash[currency] = Money.new(amount, currency)
    end
  end

  def edit; end

  def create
    @registration = @conference.registrations.new(registration_params)

    @user = if current_user.nil?
              # @user needs to be set for devise/registrations/new_embedded
              @registration.build_user(user_params)
            else
              current_user
            end

    @registration.user = @user
    authorize! :create, @registration

    if @registration.save
      # Sign in the new user
      sign_in(@registration.user) unless current_user

      MailblusterEditLeadJob.perform_later(@user.id, add_tags: ["snapcon-#{@conference.short_title}"])

      if @conference.tickets.visible.any? && !current_user.supports?(@conference)
        redirect_to conference_tickets_path(@conference.short_title),
                    notice: 'You are now registered and will be receiving E-Mail notifications.'
      else
        redirect_to conference_conference_registration_path(@conference.short_title),
                    notice: 'You are now registered and will be receiving E-Mail notifications.'
      end
    elsif @conference.registration_ticket_required? && !current_user&.supports?(@conference)
      redirect_to conference_tickets_path(@conference.short_title),
                  notice: 'You must buy a registration ticket before registering.'
    else
      flash.now[:error] = "Could not create your registration for #{@conference.title}: " \
                          "#{@registration.errors.full_messages.join('. ')}."
      render :new
    end
  end

  def update
    if @registration.update(registration_params)
      redirect_to  conference_conference_registration_path(@conference.short_title),
                   notice: 'Registration was successfully updated.'
    else
      flash.now[:error] = "Could not update your registration for #{@conference.title}: " \
                          "#{@registration.errors.full_messages.join('. ')}."
      render :edit
    end
  end

  def destroy
    if @registration.destroy
      MailblusterEditLeadJob.perform_later(current_user.id, remove_tags: ["snapcon-#{@conference.short_title}"])
      redirect_to root_path,
                  notice: "You are not registered for #{@conference.title} anymore!"
    else
      redirect_to conference_conference_registration_path(@conference.short_title),
                  error: "Could not delete your registration for #{@conference.title}: " \
                         "#{@registration.errors.full_messages.join('. ')}."
    end
  end

  protected

  def set_registration
    @registration = Registration.find_by(conference: @conference, user: current_user)
    unless @registration
      redirect_to new_conference_conference_registration_path(@conference.short_title),
                  error: "Can't find a registration for #{@conference.title} for you. Please register."
    end
  end

  def user_params
    params.require(:user).permit(:username, :email, :name, :password, :password_confirmation)
  end

  def registration_params
    params.require(:registration)
          .permit(
            :conference_id,
            :volunteer, :accepted_code_of_conduct,
            vchoice_ids: [], qanswer_ids: [],
            qanswers_attributes: [],
            event_ids: [],
            user_attributes: %i[
              username email name password password_confirmation
            ]
          )
  end
end
