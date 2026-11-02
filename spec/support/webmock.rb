# frozen_string_literal: true

# Selenium Manager fetches browsers and drivers in its own process,
# so WebMock never sees those requests.

# Allow stripe.com for stripe integration tests
allowed_urls = ['stripe.com']

WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_urls)
