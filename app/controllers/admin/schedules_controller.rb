# frozen_string_literal: true

module Admin
  class SchedulesController < Admin::BaseController
    # By authorizing 'conference' resource, we can ensure there will be no unauthorized access to
    # the schedule of a conference, which should not be accessed in the first place
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
      @conference = Conference.find_by!(short_title: params[:conference_id])
      authorize! :update, @conference

      if params[:schedule] && params[:schedule][:file].present?
        file = params[:schedule][:file]
        CSV.foreach(file.path, headers: true) do |row|
          next if row['Event_ID'].blank? || row['Date'].blank? || row['Start_Time'].blank? || row['Room'].blank?

          begin
            event_date = Date.strptime(row['Date'], '%m/%d/%y')
            event_time = Time.parse(row['Start_Time'])
            event_start_time = DateTime.new(event_date.year, event_date.month, event_date.day, event_time.hour, event_time.min, event_time.sec, event_time.zone)
            room = Room.find_or_create_by(name: row['Room'])
            event = Event.find_by(id: row['Event_ID'])

            if event
              event.update(start_time: event_start_time, room: room)
            else
              Rails.logger.warn "Event not found with ID: #{row['Event_ID']}"
            end
          rescue StandardError => e
            Rails.logger.error "Error processing row: #{row.to_h}, Error: #{e.message}"
            next
          end
        end
        flash[:notice] = 'Schedule uploaded successfully!'
      else
        flash[:alert] = 'No file was attached!'
      end
      redirect_to admin_conference_schedules_path(@conference)
    end

    private
    
    def schedule_params
      params.require(:schedule).permit(:track_id) if params[:schedule]
    end
  end
end
