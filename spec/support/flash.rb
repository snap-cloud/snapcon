# frozen_string_literal: true

# SnapCon feature specs read the flash with `expect(flash).to eq(...)`.
# Upstream OSEM replaced this helper with `within('#flash') { ... }`.
module Flash
  def flash
    results = all(:css, 'div#flash p')
    return 'none' if results.empty?

    raise "One flash expected, but we had #{results.map(&:text).inspect}" if results.size > 1

    results.first.text
  end
end
