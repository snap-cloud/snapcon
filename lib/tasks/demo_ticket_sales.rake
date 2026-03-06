# frozen_string_literal: true

namespace :data do
  desc 'Add demo paid ticket sales (USD + EUR) for testing "Gross ticket sales by currency" chart. Usage: CONF=123123 rake data:demo_ticket_sales'
  task demo_ticket_sales: :environment do
    short_title = ENV['CONF'] || Conference.first&.short_title
    conference = Conference.find_by(short_title: short_title)
    unless conference
      puts "Conference not found. Set CONF=short_title (e.g. CONF=123123) or create a conference first."
      next
    end

    base_currency = conference.tickets.first&.price_currency || 'USD'
    # Ensure we have a non-free ticket for paid sales
    paid_ticket = conference.tickets.find_by(registration_ticket: false).presence || conference.tickets.first
    unless paid_ticket
      puts "No ticket found for conference #{short_title}."
      next
    end

    # If ticket is free, create a paid "Supporter" ticket
    if paid_ticket.price_cents.zero?
      paid_ticket = conference.tickets.create!(
        title: 'Supporter',
        price_cents: 2_000,
        price_currency: base_currency,
        description: 'Demo paid ticket',
        registration_ticket: false,
        visible: true
      )
      puts "Created paid ticket: #{paid_ticket.title} (#{Money.new(paid_ticket.price_cents, base_currency).format})"
    end

    # Add EUR conversion so "enabled currencies" includes EUR
    if base_currency == 'USD' && conference.currency_conversions.find_by(from_currency: 'USD', to_currency: 'EUR').blank?
      conference.currency_conversions.create!(from_currency: 'USD', to_currency: 'EUR', rate: 0.92)
      puts 'Added USD -> EUR conversion (rate 0.92).'
    end

    user1 = User.first || User.create!(email: 'demo1@example.com', name: 'Demo User 1', password: 'password123456', confirmed_at: Time.current)
    user2 = User.second || User.create!(email: 'demo2@example.com', name: 'Demo User 2', password: 'password123456', confirmed_at: Time.current)

    # Payment + purchase in USD
    payment_usd = Payment.create!(conference: conference, user: user1, currency: 'USD', status: :success, amount: 5_000)
    purchase_usd = TicketPurchase.new(
      conference: conference, user: user1, ticket: paid_ticket,
      quantity: 2, currency: 'USD', amount_paid_cents: 2_500, amount_paid: 25.0
    )
    purchase_usd.payment = payment_usd
    purchase_usd.save!(validate: false)
    purchase_usd.update_columns(paid: true)
    purchase_usd.quantity.times { purchase_usd.physical_tickets.create! }
    puts "Created USD purchase: 2 x #{paid_ticket.title} = $50 (5000 cents)."

    # Payment + purchase in EUR (if base is USD and we have conversion)
    if conference.currency_conversions.exists?(to_currency: 'EUR')
      payment_eur = Payment.create!(conference: conference, user: user2, currency: 'EUR', status: :success, amount: 4_600)
      purchase_eur = TicketPurchase.new(
        conference: conference, user: user2, ticket: paid_ticket,
        quantity: 1, currency: 'EUR', amount_paid_cents: 4_600, amount_paid: 46.0
      )
      purchase_eur.payment = payment_eur
      purchase_eur.save!(validate: false)
      purchase_eur.update_columns(paid: true)
      purchase_eur.physical_tickets.create!
      puts "Created EUR purchase: 1 x #{paid_ticket.title} = 46 EUR (4600 cents)."
    end

    puts "Done. Refresh the Ticket Purchases page to see the 'Gross ticket sales by currency' chart."
  end
end
