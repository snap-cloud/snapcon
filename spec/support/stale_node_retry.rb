# frozen_string_literal: true

# Chrome 157's chromedriver reports an element from a replaced document
# (e.g. after a Turbolinks visit) as an "unknown error" instead of a stale
# element reference. Capybara only retries the latter, so translate it.
module StaleNodeAsStaleElement
  STALE_NODE = /Node with given id does not belong to the document/

  private

  def execute(*)
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.match?(STALE_NODE)

    raise Selenium::WebDriver::Error::StaleElementReferenceError.new(e.message)
  end
end

Selenium::WebDriver::Remote::Bridge.prepend(StaleNodeAsStaleElement)
