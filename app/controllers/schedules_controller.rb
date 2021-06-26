# frozen_string_literal: true

class SchedulesController < ApplicationController
  include ConferenceHelper

  load_and_authorize_resource
  before_action :respond_to_options
  before_action :favourites
  load_resource :conference, find_by: :short_title
  load_resource :program, through: :conference, singleton: true, except: :index
  before_action :load_withdrawn_event_schedules, only: [:show, :events]

  def show
    event_schedules = @program.event_schedule_for_fullcalendar

    unless event_schedules
      redirect_to events_conference_schedule_path(@conference.short_title)
      return
    end

    respond_to do |format|
      format.xml do
        @events_xml = event_schedules.map(&:event).group_by{ |event| event.time.to_date } if event_schedules
      end
      format.ics do
        cal = Icalendar::Calendar.new
        cal = icalendar_proposals(cal, event_schedules.map(&:event), @conference)
        cal.publish
        render inline: cal.to_ical
      end

      format.html do
        dates = @conference.start_date..@conference.end_date
        # the schedule takes you to today if it is a date of the schedule
        current_day = @conference.current_conference_day
        @day = current_day.present? ? current_day : dates.first

        if current_user && @favourites
          event_schedules = event_schedules.select{ |e| e.event.planned_for_user?(current_user) }
        end

        @rooms = FullCalendarFormatter.rooms_to_resources(@conference.rooms) if @conference.rooms
        @event_schedules = FullCalendarFormatter.event_schedules_to_resources(event_schedules)
        @now = Time.now.in_time_zone(@conference.timezone).strftime('%FT%T%:z')
      end
    end
  end

  def events
    @dates = @conference.start_date..@conference.end_date
    @events_schedules = @program.event_schedule_for_fullcalendar || []

    if current_user && @favourites
      @events_schedules = @events_schedules.select{ |e| e.event.planned_for_user?(current_user) }
    end

    @unscheduled_events = if @program.selected_schedule
                            @program.events.confirmed - @events_schedules.map(&:event)
                          else
                            @program.events.confirmed
                          end
    @unscheduled_events = @unscheduled_events.select{ |e| e.planned_for_user?(current_user) } if current_user && @favourites

    day = @conference.current_conference_day
    @tag = day.strftime('%Y-%m-%d') if day
  end

  def happening_now
    # TODO: Adapt to include happening next.
    @events_schedules = get_happening_now_events_schedules(@conference)
    @current_time = Time.now.in_time_zone(@conference.timezone)

    respond_to do |format|
      format.html
      format.json { render json: @events_schedules.to_json(root: false, include: :event) }
    end
  end

  def vertical_schedule
    redirect_to conference_schedule_path(@conference)
  end

  def app
    @qr_code = RQRCode::QRCode.new(conference_schedule_url).as_svg(offset: 20, color: '000', shape_rendering: 'crispEdges', module_size: 11)
  end

  private

  def favourites
    @favourites = params[:favourites] == 'true'
  end

  def respond_to_options
    respond_to do |format|
      format.html { head :ok }
    end if request.options?
  end

  def load_withdrawn_event_schedules
    # Avoid making repetitive EXISTS queries for these later.
    # See usage in EventsHelper#canceled_replacement_event_label
    @withdrawn_event_schedules = EventSchedule.withdrawn_or_canceled_event_schedules(@program.schedule_ids)
  end
end
