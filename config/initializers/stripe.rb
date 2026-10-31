# frozen_string_literal: true

Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', nil)

# Pin the API version instead of using the Stripe account's default.
# Payment#complete_checkout expands `payment_intent.latest_charge`, which only
# exists from 2022-11-15 on. Change this deliberately, after testing checkout.
Stripe.api_version = '2022-11-15'
