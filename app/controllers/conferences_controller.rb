# frozen_string_literal: true

class ConferencesController < ApplicationController
  include ConferenceHelper

  protect_from_forgery with: :null_session
  before_action :respond_to_options
  load_and_authorize_resource find_by: :short_title, except: :show

  def index
    @current    = Conference.upcoming.reorder(start_date: :asc)
    @antiquated = Conference.past.joins(:splashpage).where(splashpage: { public: true }).includes(:venue, :program, :splashpage, :registration_period)
    render :new_install if @antiquated.empty? && @current.empty? && User.empty?
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def show
    # load conference with header content
    @conference = Conference.unscoped.eager_load(
      :splashpage,
      :program,
      :registration_period,
      :contact,
      venue: :commercial
    ).find_by!(conference_finder_conditions)
    authorize! :show, @conference # TODO: reduce the 10 queries performed here

    @splashpage = @conference.splashpage

    redirect_to admin_conference_splashpage_path(@conference.short_title) && return unless @splashpage.present?

    # User messages at the top of the page.
    @unpaid_tickets = current_user_has_unpaid_tickets?
    @user_needs_to_register = current_user_needs_to_register?

    @image_url = @splashpage.banner_photo_url || @conference.picture_url

    if @splashpage.include_cfp?
      cfps = @conference.program.cfps
      @call_for_events = cfps.find { |call| call.cfp_type == 'events' }
      if @call_for_events.try(:open?)
        @event_types = @conference.event_types.pluck(:title)
        @track_names = @conference.confirmed_tracks.pluck(:name).sort
      end
      @call_for_tracks = cfps.find { |call| call.cfp_type == 'tracks' }
      @call_for_booths = cfps.find { |call| call.cfp_type == 'booths' }
    end
    if @splashpage.include_program?
      @highlights = @conference.highlighted_events.includes(:speakers, :speaker_event_users)
      if @splashpage.include_tracks?
        @tracks = @conference.confirmed_tracks.eager_load(
          :room
        ).order('tracks.name')
      end
      @booths = @conference.confirmed_booths.order('title') if @splashpage.include_booths?
      load_happening_now if @splashpage.include_happening_now
    end
    if @splashpage.include_registrations? || @splashpage.include_tickets?
      @tickets = @conference.tickets.visible.order('price_cents')
    end
    @lodgings = @conference.lodgings.order('id') if @splashpage.include_lodgings?
    if @splashpage.include_sponsors?
      @sponsorship_levels = @conference.sponsorship_levels.eager_load(
        :sponsors
      ).order('sponsorship_levels.position ASC', 'sponsors.name')
      @sponsors = @conference.sponsors
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def calendar
    respond_to do |format|
      format.ics do
        calendar = Icalendar::Calendar.new
        Conference.all.each do |conf|
          if params[:full]
            event_schedules = conf.program.selected_event_schedules(
              includes: [{ event: %i[event_type speakers submitter] }]
            )
            calendar = icalendar_proposals(calendar, event_schedules.map(&:event), conf)
          else
            calendar.event do |e|
              e.dtstart = conf.start_date
              e.dtstart.ical_params = { 'VALUE'=>'DATE' }
              e.dtend = conf.end_date
              e.dtend.ical_params = { 'VALUE'=>'DATE' }
              e.duration = "P#{(conf.end_date - conf.start_date + 1).floor}D"
              e.created = conf.created_at
              e.last_modified = conf.updated_at
              e.summary = conf.title
              e.description = conf.description
              e.uid = conf.guid
              e.url = conference_url(conf.short_title)
              v = conf.venue
              if v
                e.geo = v.latitude, v.longitude if v.latitude && v.longitude
                location = ''
                location += "#{v.street}, " if v.street
                location += "#{v.postalcode} #{v.city}, " if v.postalcode && v.city
                location += v.country_name if v.country_name
                e.location = location if location
              end
            end
          end
        end
        calendar.publish
        render inline: calendar.to_ical
      end
    end
  end

  private

  def conference_finder_conditions
    if params[:id]
      { short_title: params[:id] }
    else
      { custom_domain: request.domain }
    end
  end

  def respond_to_options
    if request.options?
      respond_to do |format|
        format.html { head :ok }
      end
    end
  end

  def current_user_tickets
    @current_user_tickets ||= current_user.ticket_purchases.by_conference(@conference)
  end

  def current_user_needs_to_register?
    current_user && !@conference.user_registered?(current_user) &&
      current_user_tickets.where(ticket: @conference.registration_tickets).paid.any?
  end

  def current_user_has_unpaid_tickets?
    current_user && current_user_tickets.unpaid.any?
  end
end
