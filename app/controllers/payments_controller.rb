# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def new
    @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false)
    if @total_amount_to_pay.zero?
      raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
    end

    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
  end

  def create
    @payment = Payment.new(payment_params)
    checkout_session = create_stripe_checkout(unpaid_tickets_for_user)

    @payment.amount = @payment.amount_to_pay

    if checkout_session.url
      @payment.authorization_code = session.id
      @payment.status = :pending
      @payment.save
      redirect_to checkout_session.url, status: 303
    else
      @payment.status = :failure
      @payment.save
      flash[:error] = "#{@payment.errors&.full_messages.to_sentence} Please try again with correct credentials."
      redirect_to new_conference_payment_path(@conference)
    end
  end

  def success
    @payment = Payment.find_by(authorization_code: params[:session_id])
    update_purchased_ticket_purchases

    has_registration_ticket = current_user.tickets.for_registration(@conference).present?
    if has_registration_ticket
      redirect_to new_conference_conference_registration_path(@conference.short_title),
                  notice: 'Thanks! Your ticket is booked successfully. Please register for the conference.'
    else
      redirect_to conference_physical_tickets_path,
                  notice: 'Thanks! Your ticket is booked successfully.'
    end
  end

  def cancel
    unpaid_tickets_for_user.destroy_all
    flash[:notice] = 'Your payment has been cancelled.'
  end

  private

  def payment_params
    params.permit(:stripe_customer_email, :stripe_customer_token)
          .merge(stripe_customer_email: params[:stripeEmail],
                 stripe_customer_token: params[:stripeToken],
                 user: current_user, conference: @conference)
  end

  def create_stripe_checkout(ticket_purchases)
    methods = %w|card|
    if euro_currency?
      methods << %w|sepa_debit|
    end
    puts "STRIPE METHODS #{methods}"
    puts ticket_purchases.map(&:ticket).map(&:price_currency)
    Stripe::Checkout::Session.create(
      payment_method_types: methods,
      line_items:           ticket_purchases.map(&:stripe_line_item),
      mode:                 'payment',
      success_url:          "#{success_conference_payments_url(@conference.short_title)}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url:           "#{cancel_conference_payments_url(@conference.short_title)}?session_id={CHECKOUT_SESSION_ID}",
    )
  end

  def euro_currency?
    unpaid_tickets_for_user.map(&:ticket).all? { |t| t.price_currency == 'EUR' }
  end

  def unpaid_tickets_for_user
    @unpaid_tickets_for_user ||= current_user.ticket_purchases.by_conference(@conference).unpaid
  end

  def update_purchased_ticket_purchases
    # REFACTOR: Move to method on Payment
    unpaid_tickets_for_user.each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end
end
