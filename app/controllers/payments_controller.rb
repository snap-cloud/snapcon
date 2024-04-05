# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def index
    @payments = current_user.payments
  end

  def new
    # TODO: use "base currency"
    session[:selected_currency] = params[:currency] if params[:currency].present?
    selected_currency = session[:selected_currency] || 'USD'
    from_currency = 'USD'

    @total_amount_to_pay = CurrencyConversion.convert_currency(@conference, Ticket.total_price(@conference, current_user, paid: false), from_currency, selected_currency)
    raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment) if @total_amount_to_pay.zero?
    raise CanCan::AccessDenied.new('Selected currency is invalid!', :new, Payment) if @total_amount_to_pay < 0
    @has_registration_ticket = params[:has_registration_ticket]
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
    # a way to display the currency values in the view, but there might be a better way to do this.
    @converted_prices = {}
    @unpaid_ticket_purchases.each do |ticket_purchase|
      @converted_prices[ticket_purchase.id] = ticket_purchase.amount_paid
    end
    @currency = selected_currency
  end

  def create
    @payment = Payment.new(payment_params)

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
      @total_amount_to_pay = convert_currency(@conference, Ticket.total_price(@conference, current_user, paid: false), from_currency, selected_currency)
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
                 user: current_user, conference: @conference, currency: session[:selected_currency])
  end

  def update_purchased_ticket_purchases
    current_user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end
end
