# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource only: %i[index new]
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def index
    @payments = current_user.payments
  end

  def new
    session[:selected_currency] = params[:currency] if params[:currency].present?
    selected_currency = session[:selected_currency] || @conference.tickets.first.price_currency
    from_currency = @conference.tickets.first.price_currency

    @total_amount_to_pay = CurrencyConversion.convert_currency(@conference, Ticket.total_price(@conference, current_user, paid: false), from_currency, selected_currency)
    raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment) if @total_amount_to_pay.zero?
    raise CanCan::AccessDenied.new('Selected currency is invalid!', :new, Payment) if @total_amount_to_pay.negative?

    @has_registration_ticket = params[:has_registration_ticket]
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)

    @currency = selected_currency
  end

  def create
    session[:selected_currency] = params[:currency] if params[:currency].present?
    selected_currency = session[:selected_currency] || @conference.tickets.first.price_currency

    @payment = Payment.new(
      user:       current_user,
      conference: @conference,
      currency:   selected_currency
    )
    authorize! :create, @payment

    unless @payment.save
      redirect_to new_conference_payment_path(@conference.short_title),
                  error: @payment.errors.full_messages.to_sentence
      return
    end

    session[:has_registration_ticket] = params[:has_registration_ticket]

    checkout_session = @payment.create_checkout_session(
      success_url: success_conference_payments_url(@conference.short_title) + '?session_id={CHECKOUT_SESSION_ID}',
      cancel_url:  cancel_conference_payments_url(@conference.short_title)
    )

    if checkout_session
      redirect_to checkout_session.url, allow_other_host: true
    else
      @payment.destroy
      redirect_to new_conference_payment_path(@conference.short_title),
                  error: @payment.errors.full_messages.to_sentence.presence || 'Could not create checkout session. Please try again.'
    end
  end

  def success
    @payment = Payment.find_by(stripe_session_id: params[:session_id])

    if @payment.nil?
      redirect_to new_conference_payment_path(@conference.short_title),
                  error: 'Payment not found. Please try again.'
      return
    end

    if @payment.complete_checkout
      update_purchased_ticket_purchases(@payment)

      has_registration_ticket = session.delete(:has_registration_ticket)
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
      redirect_to new_conference_payment_path(@conference.short_title),
                  error: 'Payment could not be completed. Please try again.'
    end
  end

  def cancel
    redirect_to new_conference_payment_path(@conference.short_title),
                notice: 'Payment was cancelled. You can try again when ready.'
  end

  private

  def update_purchased_ticket_purchases(payment)
    current_user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
      ticket_purchase.pay(payment)
    end
  end
end
