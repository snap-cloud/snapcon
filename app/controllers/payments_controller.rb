# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration
  before_action :load_currency_conversions, only: [:new, :create]

  def index
    @payments = current_user.payments
  end

  def new
    # todo: use "base currency"
    session[:selected_currency] = params[:currency] if params[:currency].present?
    selected_currency = session[:selected_currency] || 'USD'
    from_currency = "USD"

    @total_amount_to_pay = convert_currency(Ticket.total_price(@conference, current_user, paid: false).amount, from_currency, selected_currency)
    raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment) if @total_amount_to_pay.zero?

    @has_registration_ticket = params[:has_registration_ticket]
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
    #a way to display the currency values in the view, but there might be a better way to do this.
    @converted_prices = {}
    @unpaid_ticket_purchases.each do |ticket_purchase|
      @converted_prices[ticket_purchase.id] = convert_currency(ticket_purchase.price.amount, 'USD', selected_currency)
    end
    @currency = selected_currency
  end

  def create
    @payment = Payment.new (payment_params.merge(currency: session[:selected_currency]))

    if @payment.purchase && @payment.save
      update_purchased_ticket_purchases

      has_registration_ticket = params[:has_registration_ticket]
      if has_registration_ticket == 'true'
        registration = @conference.register_user(current_user)
        if registration
          redirect_to conference_physical_tickets_path,
                      notice: "Thanks! Your ticket is booked successfully and you have been registered for #{@conference.title}."
          return
        end
        redirect_to new_conference_conference_registration_path(@conference.short_title),
                    notice: 'Thanks! Your ticket is booked successfully. Please register for the conference.'
      else
        redirect_to conference_physical_tickets_path,
                    notice: 'Thanks! Your ticket is booked successfully.'
      end
    else
      @total_amount_to_pay = convert_currency(Ticket.total_price(@conference, current_user, paid: false).amount, from_currency, selected_currency)
      @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
      flash.now[:error] = @payment.errors.full_messages.to_sentence + ' Please try again with correct credentials.'
      render :new
    end
  end

  private

  def payment_params
    params.permit(:stripe_customer_email, :stripe_customer_token)
          .merge(stripe_customer_email: params[:stripeEmail],
                 stripe_customer_token: params[:stripeToken],
                 user: current_user, conference: @conference)
  end

  def update_purchased_ticket_purchases
    current_user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end

  def load_currency_conversions
    @currency_conversions = @conference.currency_conversions
  end

  def convert_currency(amount, from_currency, to_currency)
    update_rate(from_currency, to_currency)
  
    money_amount = Money.from_amount(amount, from_currency)
    converted_amount = money_amount.exchange_to(to_currency)
    converted_amount
  end
  
  def update_rate(from_currency, to_currency)
    conversion = @currency_conversions.find_by(from_currency: from_currency, to_currency: to_currency)
    if conversion
      Money.add_rate(from_currency, to_currency, conversion.rate)
    else
      #If no conversion is found. Typically only possible if base to base. Maybe make this error out.
      Money.add_rate(from_currency, to_currency, 1) unless from_currency == to_currency
    end
  end

end
