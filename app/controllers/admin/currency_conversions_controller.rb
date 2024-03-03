module Admin
  class CurrencyConversionsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :currency_conversion, through: :conference

    # GET /currency_conversions
    def index
      @currency_conversion = @conference.currency_conversions
      respond_to do |format|
        format.html
        format.json { render json: @currency_conversions }
      end
    end

    # GET /currency_conversions/1
    def show; end

    # GET /currency_conversions/new
    def new
      @currency_conversion = @conference.currency_conversions.new(conference_id: @conference.short_title)
    end

    # GET /currency_conversions/1/edit
    def edit; end

    # POST /currency_conversions
    def create
      @currency_conversion = @conference.currency_conversions.new(currency_conversion_params)

      if @currency_conversion.save
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully created.'
      else
        flash.now[:error] = 'Creating currency conversion failed.'
        render :new
      end
    end

    # PATCH/PUT /currency_conversions/1
    def update
      if @currency_conversion.update(currency_conversion_params)
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully updated.'
      else
        flash.now[:error] = 'Updating currency conversion failed.'
        render :edit
      end
    end

    # DELETE /currency_conversions/1
    def destroy
      if @currency_conversion.destroy
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully deleted.'
      else
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Deleting currency conversion failed.'
      end
    end

    private

    # Only allow a list of trusted parameters through.
    def currency_conversion_params
      params.require(:currency_conversion).permit(:from_currency, :to_currency, :rate)
    end
  end
end
