# frozen_string_literal: true

module Admin
  class VersionsController < Admin::BaseController
    load_resource :conference, find_by: :short_title, only: :index
    load_and_authorize_resource class: PaperTrail::Version

    VERSIONS_PER_PAGE = 50

    # Out-of-range or malformed ?page= values: go back to the first page.
    rescue_from Pagy::VariableError do
      redirect_to request.query_parameters.except('page').merge(only_path: true)
    end

    def index
      @conferences_with_role = if current_user.is_admin?
                                 Conference.pluck(:short_title)
                               else
                                 Conference.with_role(
                                   %i[organizer cfp info_desk], current_user
                                 ).pluck(:short_title)
                               end

      @conferences_with_role.uniq!

      @versions = PaperTrail::Version.where(conference_id: @conference.id).accessible_by(current_ability) if @conference.present?

      # Each row deserializes YAML and runs several lookups, so never render
      # the full history in one request.
      @pagy, @versions = pagy(@versions.reorder(id: :desc), items: VERSIONS_PER_PAGE)
    end

    def revert_attribute
      if params[:attribute] && @version.changeset.reject do |_, values|
           values[0].blank? && values[1].blank?
         end.keys.include?(params[:attribute])
        if @version.item[params[:attribute]] == @version.changeset[params[:attribute]][0]
          flash[:error] = 'The item is already in the state that you are trying to revert it back to'

        else
          @version.item[params[:attribute]] = @version.changeset[params[:attribute]][0]
          if @version.item.save
            flash[:notice] = 'The selected change was successfully reverted'
          else
            flash[:error] =
              "An error prohibited this change from being reverted: #{@version.item.errors.full_messages.join('. ')}."
          end
        end

      else
        flash[:error] = 'Revert failed. Attribute missing or invalid'
      end

      redirect_back_or_to admin_revision_history_path
    end

    def revert_object
      if @version.event != 'create'
        if @version.reify.save
          flash[:notice] = 'The selected change was successfully reverted'
        else
          flash[:error] =
            "An error prohibited this change from being reverted: #{@version.reify.errors.full_messages.join('. ')}."
        end

      elsif @version.event == 'create' && @version.item
        # if @version represents a create event and is not currently deleted
        @version.item.destroy
        flash[:notice] = 'The selected change was successfully reverted'

      else
        flash[:error] = 'The item is already in the state that you are trying to revert it back to'
      end

      redirect_back_or_to admin_revision_history_path
    end
  end
end
