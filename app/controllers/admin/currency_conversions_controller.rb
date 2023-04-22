module Admin
  class CurrencyConversionsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :currency_conversion, through: :conference

    # GET /currency_conversions
    def index; end

    # GET /currency_conversions/1
<<<<<<< HEAD
    def show; end
=======
    def show
    end
>>>>>>> 34525cbc4 (routes are working except update)

    # GET /currency_conversions/new
    def new
      @currency_conversion = @conference.currency_conversions.new(conference_id: @conference.short_title)
    end

    # GET /currency_conversions/1/edit
<<<<<<< HEAD
    def edit; end
=======
    def edit
    end
>>>>>>> 34525cbc4 (routes are working except update)

    # POST /currency_conversions
    def create
      @currency_conversion = @conference.currency_conversions.new(currency_conversion_params)

      if @currency_conversion.save
<<<<<<< HEAD
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully created.'
      else
        flash.now[:error] = 'Creating currency conversion failed.'
=======
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: "Currency conversion was successfully created."
      else
        flash.now[:error] = "Creating currency conversion failed."
>>>>>>> 34525cbc4 (routes are working except update)
        render :new
      end
    end

    # PATCH/PUT /currency_conversions/1
    def update
      if @currency_conversion.update(currency_conversion_params)
<<<<<<< HEAD
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully updated.'
      else
        flash.now[:error] = 'Updating currency conversion failed.'
=======
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: "Currency conversion was successfully updated."
      else
        flash.now[:error] = "Updating currency conversion failed."
>>>>>>> 34525cbc4 (routes are working except update)
        render :edit
      end
    end

    # DELETE /currency_conversions/1
    def destroy
      if @currency_conversion.destroy
<<<<<<< HEAD
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Currency conversion was successfully deleted.'
      else
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: 'Deleting currency conversion failed.'
=======
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: "Currency conversion was successfully deleted."
      else
        redirect_to admin_conference_currency_conversions_path(@conference.short_title), notice: "Deleting currency conversion failed."
>>>>>>> 34525cbc4 (routes are working except update)
      end
    end

    private

<<<<<<< HEAD
    # Only allow a list of trusted parameters through.
    def currency_conversion_params
      params.require(:currency_conversion).permit(:from_currency, :to_currency, :rate)
    end
=======
      # Only allow a list of trusted parameters through.
      def currency_conversion_params
        params.require(:currency_conversion).permit(:from_currency, :to_currency, :rate)
      end
>>>>>>> 34525cbc4 (routes are working except update)
  end
end
