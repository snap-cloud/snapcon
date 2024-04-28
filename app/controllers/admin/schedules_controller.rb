# frozen_string_literal: true

module Admin
  class SchedulesController < Admin::BaseController
    # By authorizing 'conference' resource, we can ensure there will be no unauthorized access to
    # the schedule of a conference, which should not be accessed in the first place
    before_action :set_conference
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :program, through: :conference, singleton: true
    load_and_authorize_resource :schedule, through: :program, except: %i[new create]
    load_resource :event_schedules, through: :schedule
    load_resource :selected_schedule, through: :program, singleton: true
    load_resource :venue, through: :conference, singleton: true

    def index; end

    def new
      @schedule = @program.schedules.build(track: @program.tracks.new)
      authorize! :new, @schedule
    end

    def create
      @schedule = @program.schedules.new(schedule_params)
      authorize! :create, @schedule
      if @schedule.save
        redirect_to admin_conference_schedule_path(@conference.short_title, @schedule.id),
                    notice: 'Schedule was successfully created.'
      else
        redirect_to admin_conference_schedules_path(conference_id: @conference.short_title),
                    error: "Could not create schedule. #{@schedule.errors.full_messages.join('. ')}."
      end
    end

    def show
      @event_schedules = @schedule.event_schedules.eager_load(
        room:  :tracks,
        event: [
          :difficulty_level,
          :track,
          :event_type,
          { event_users: :user }
        ]
      )
      @event_types = @program.event_types || []

      if @schedule.track
        track = @schedule.track
        @unscheduled_events = track.events.confirmed - @schedule.events
        @dates = track.start_date..track.end_date
        @rooms = [track.room]
      else
        @program.tracks.self_organized.confirmed.each do |t|
          @event_schedules += t.selected_schedule.event_schedules if t.selected_schedule
        end
        self_organized_tracks_events = Event.eager_load(event_users: :user).confirmed.where(track: @program.tracks.self_organized.confirmed)
        @unscheduled_events = (@program.events.confirmed + @program.events.unconfirmed) - @schedule.events - self_organized_tracks_events
        @dates = @conference.start_date..@conference.end_date
        @rooms = @conference.venue.rooms if @conference.venue
      end
    end

    def destroy
      if @schedule.destroy
        redirect_to admin_conference_schedules_path(conference_id: @conference.short_title),
                    notice: 'Schedule successfully deleted.'
      else
        redirect_to admin_conference_schedules_path(conference_id: @conference.short_title),
                    error: "Schedule couldn't be deleted. #{@schedule.errors.full_messages.join('. ')}."
      end
    end

    def upload_csv
      authorize! :update, @conference
      return flash[:alert] = 'No file was attached!' unless file_present?

      if process_csv
        flash[:notice] = 'Schedule uploaded successfully!'
      else
        flash[:alert] = 'Failed to process CSV file.'
      end

      redirect_to admin_conference_schedules_path(@conference)
    end

    private

    def set_conference
      @conference = Conference.find_by!(short_title: params[:conference_id])
    end

    def file_present?
      params[:schedule] && params[:schedule][:file].present?
    end

    def process_csv
      file = params[:schedule][:file]
      CSV.foreach(file.path, headers: true) do |row|
        process_row(row)
      end
      true
    rescue StandardError => e
      Rails.logger.error "CSV Processing Error: #{e.message}"
      false
    end

    def process_row(row)
      event_date = parse_date(row['Date'])
      event_time = parse_time(row['Start_Time'])
      event_start_time = combine_datetime(event_date, event_time)

      room = Room.find_or_create_by(name: row['Room'])
      event = Event.find_by(id: row['Event_ID'])

      event&.update(start_time: event_start_time, room: room)
    end

    def parse_date(date_str)
      Date.strptime(date_str, '%m/%d/%y')
    end

    def parse_time(time_str)
      Time.parse(time_str)
    end

    def combine_datetime(date, time)
      DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
    end

    def schedule_params
      params.require(:schedule).permit(:track_id) if params[:schedule]
    end
  end
end
