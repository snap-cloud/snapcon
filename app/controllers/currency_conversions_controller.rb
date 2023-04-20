class CurrencyConversionsController < ApplicationController
  before_action :set_currency_conversion, only: %i[ show edit update destroy ]

  # GET /currency_conversions
  def index
    @currency_conversions = CurrencyConversion.all
  end

  # GET /currency_conversions/1
  def show
  end

  # GET /currency_conversions/new
  def new
    @currency_conversion = CurrencyConversion.new
  end

  # GET /currency_conversions/1/edit
  def edit
  end

  # POST /currency_conversions
  def create
    @currency_conversion = CurrencyConversion.new(currency_conversion_params)

    if @currency_conversion.save
      redirect_to @currency_conversion, notice: "Currency conversion was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /currency_conversions/1
  def update
    if @currency_conversion.update(currency_conversion_params)
      redirect_to @currency_conversion, notice: "Currency conversion was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /currency_conversions/1
  def destroy
    @currency_conversion.destroy
    redirect_to currency_conversions_url, notice: "Currency conversion was successfully destroyed."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_currency_conversion
      @currency_conversion = CurrencyConversion.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def currency_conversion_params
      params.fetch(:currency_conversion, {})
    end
end
