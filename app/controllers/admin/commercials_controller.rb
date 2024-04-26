# frozen_string_literal: true

module Admin
  class CommercialsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource through: :conference, except: %i[new create]

    def index
      @commercials = @conference.commercials

      @commercial = @conference.commercials.build
    end

    def create
      @commercial = @conference.commercials.build(commercial_params)
      authorize! :create, @commercial

      if @commercial.save
        redirect_to admin_conference_commercials_path,
                    notice: 'Materials were successfully created.'
      else
        redirect_to admin_conference_commercials_path,
                    error: 'An error prohibited materials from being saved: ' \
                           "#{@commercial.errors.full_messages.join('. ')}."

      end
    end

    def update
      if @commercial.update(commercial_params)
        redirect_to admin_conference_commercials_path,
                    notice: 'Materials were successfully updated.'
      else
        redirect_to admin_conference_commercials_path,
                    error: 'An error prohibited materials from being saved: ' \
                           "#{@commercial.errors.full_messages.join('. ')}."
      end
    end

    def destroy
      @commercial.destroy
      redirect_to admin_conference_commercials_path, notice: 'Materials were successfully removed.'
    end

    def render_commercial
      result = Commercial.render_from_url(params[:url])
      if result[:error]
        render plain: result[:error], status: :bad_request
      else
        render plain: result[:html]
      end
    end

    ##
    # Received a file from user
    # Reads file and creates commercial for event
    # File content example:
    # EventID, Title, URL
    def mass_upload
      errors = Commercial.read_file(params[:file]) if params[:file]

      if !params[:file]
        flash[:error] = 'Empty file detected while adding materials to Event'
      elsif errors.present?
        errors_text = aggregate_errors(errors)
        flash[:notice] = if errors_text.length > 4096
                           'Errors are too long to be displayed. Please check the logs.'
                         else
                           errors_text
                         end

      else
        flash[:notice] = 'Successfully added materials.'
      end
      redirect_back(fallback_location: root_path)
    end

    private

    # Aggregate errors and ensure that they do not exceed 4 KB in total size
    def aggregate_errors(errors)
      errors_text = ''
      if errors[:no_event].any?
        errors_text += 'Unable to find events with IDs: ' + errors[:no_event].join(', ') + '. '
      end
      if errors[:validation_errors].any?
        errors_text += 'Validation errors: ' + errors[:validation_errors].join('. ')
      end
      errors_text
    end

    def commercial_params
      params.require(:commercial).permit(:title, :url).tap do |params|
        params[:url] = Commercial.generate_snap_embed(params[:url]) if params[:url]
      end
    end
  end
end
