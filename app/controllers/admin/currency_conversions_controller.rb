module Admin
  class CurrencyConversionsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :currency_conversion, through: :conference
    before_action :check_for_tickets, only: [:new, :create, :edit]
    before_action :set_currency_options, only: [:new, :create, :edit]

    # GET /currency_conversions
    def index; end

    # GET /currency_conversions/1
    def show; end

    # GET /currency_conversions/new
    def new
      @currency_conversion = @conference.currency_conversions.new(conference_id: @conference.short_title)
      @currency_conversion.from_currency = @conference.tickets.first.price_currency
    end

    # GET /currency_conversions/1/edit
    def edit; end

    # POST /currency_conversions
    def create
      @currency_conversion = @conference.currency_conversions.new(currency_conversion_params)
      @currency_conversion.from_currency = @conference.tickets.first.price_currency
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
      params.require(:currency_conversion).permit(:to_currency, :rate)
    end

    def set_currency_options
      @currency_conversion.from_currency = @conference.tickets.first.price_currency
      @to_currency_options = CurrencyConversion::VALID_CURRENCIES.reject { |i| i == @currency_conversion.from_currency }
    end

    def check_for_tickets
      if @conference.tickets.empty?
        redirect_to admin_conference_currency_conversions_path, alert: 'No tickets available for this conference. Cannot create or edit currency conversions.'
      end
    end
  end
end
