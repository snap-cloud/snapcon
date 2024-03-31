# frozen_string_literal: true

class TicketsController < ApplicationController
  before_action :authenticate_user!
  load_resource :conference, find_by: :short_title
  before_action :load_tickets
  before_action :load_currency_conversions, only: :index
  authorize_resource :ticket, through: :conference
  authorize_resource :conference_registrations, class: Registration
  before_action :check_load_resource, only: :index

  def index
    # Clear out unpaid tickets so a user can reselect registration tickets.
    current_user.ticket_purchases.unpaid.delete_all
  end

  def check_load_resource
    redirect_to root_path, notice: "There are no tickets available for #{@conference.title}!" if @tickets.empty?
  end

  def load_tickets
    @tickets = @conference.tickets.visible.order(:title)
  end

  def load_currency_conversions
    @currency_conversions = @conference.currency_conversions
    @currencies = [@conference.tickets.first.price_currency]
    @currencies |= @currency_conversions.map(&:to_currency).uniq
    @currency_meta = @currencies.map do |currency|
      currency_conversion = @currency_conversions.find { |c| c.to_currency == currency }
      rate = if currency_conversion
               currency_conversion.rate
             else
               1
             end
      symbol = Money::Currency.new(currency).symbol
      { currency: currency, rate: rate, symbol: symbol }
    end
  end
end
