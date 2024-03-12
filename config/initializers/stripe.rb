Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY') { Rails.application.secrets.stripe_secret_key }
