# frozen_string_literal: true

# Visual regression screenshots, see docs/visual-regression.md.
#
# With SCREENSHOTS=1, every feature spec runs in the JavaScript driver and saves
# full-page screenshots to tmp/screenshots (or SCREENSHOT_DIR):
#
#   <spec file>/<example>/<NN>-<controller>-<action>.png
#
# A page is captured just before the spec navigates away from it, and once more
# when the example ends. Failed examples leave no screenshots here.
module Screenshots
  NAVIGATING_ACTIONS = %i[visit click_link click_button click_on].freeze
  # The desktop layout; the spec default window is narrow enough to collapse the navbar.
  WINDOW_SIZE = '1280,900'
  # Pages print timestamps, so every example runs at the same moment.
  FROZEN_TIME = Time.utc(2026, 1, 15, 12, 0, 0)

  class << self
    attr_accessor :recorder

    def enabled?
      ENV['SCREENSHOTS'].present?
    end

    def root
      Rails.root.join(ENV.fetch('SCREENSHOT_DIR', 'tmp/screenshots'))
    end

    def capture(session)
      recorder&.capture(session)
    end
  end

  # Saves the screenshots of a single example.
  class Recorder
    attr_reader :dir

    def initialize(example)
      spec_file = File.basename(example.metadata[:file_path], '_spec.rb')
      @dir = Screenshots.root.join(spec_file, example.full_description.parameterize[0, 150])
      @count = 0
      @last_digest = nil
      FileUtils.rm_rf(@dir)
    end

    # A screenshot must never fail the spec it is taken in, so errors (an open
    # alert, a closed window) only skip the capture.
    def capture(session)
      return unless page_loaded?(session)

      wait_for_ajax(session)
      png = full_page_png(session)
      digest = Digest::SHA256.hexdigest(png)
      return if digest == @last_digest

      @last_digest = digest
      @count += 1
      FileUtils.mkdir_p(@dir)
      File.binwrite(@dir.join(format('%<count>02d-%<route>s.png', count: @count, route: route_name(session))), png)
    rescue StandardError => e
      warn "Screenshot skipped: #{e.class}: #{e.message.lines.first}"
    end

    def discard
      FileUtils.rm_rf(@dir)
    end

    private

    def page_loaded?(session)
      session.driver.is_a?(Capybara::Selenium::Driver) && session.current_url.start_with?('http')
    end

    # Lets in-flight requests finish, so the page is complete. It also keeps
    # DataTables from raising an "Ajax error" alert when the spec then leaves
    # a page whose table is still loading.
    def wait_for_ajax(session)
      Timeout.timeout(Capybara.default_max_wait_time) do
        sleep 0.05 until session.evaluate_script('window.jQuery ? jQuery.active : 0').zero?
      end
    rescue Timeout::Error
      nil
    end

    # Chrome only screenshots the viewport by default; ask DevTools for the whole document.
    def full_page_png(session)
      browser = session.driver.browser
      # a blinking text cursor would differ between runs
      browser.execute_script("document.documentElement.style.caretColor = 'transparent'")
      return browser.screenshot_as(:png) unless browser.respond_to?(:execute_cdp)

      size = browser.execute_cdp('Page.getLayoutMetrics')['cssContentSize']
      clip = { x: 0, y: 0, width: size['width'], height: size['height'], scale: 1 }
      shot = browser.execute_cdp('Page.captureScreenshot', format: 'png', captureBeyondViewport: true, clip: clip)
      Base64.decode64(shot['data'])
    end

    def route_name(session)
      route = Rails.application.routes.recognize_path(URI.parse(session.current_url).path)
      "#{route[:controller]}-#{route[:action]}".tr('/_', '-')
    rescue ActionController::RoutingError, URI::InvalidURIError
      'unknown'
    end
  end

  # Captures the current page before the session leaves it.
  module SessionHooks
    NAVIGATING_ACTIONS.each do |action|
      define_method(action) do |*args, **options, &block|
        Screenshots.capture(self)
        super(*args, **options, &block)
      end
    end
  end
end

if Screenshots.enabled?
  Capybara::Session.prepend(Screenshots::SessionHooks)

  RSpec.configure do |config|
    config.before(:suite) do
      Capybara.register_driver :screenshots do |app|
        args = %W[--headless --no-sandbox --disable-gpu --window-size=#{Screenshots::WINDOW_SIZE}]
        options = Selenium::WebDriver::Chrome::Options.new(args: args)
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      end
      # rack_test cannot take screenshots, so every feature spec runs in Chrome
      Capybara.default_driver = Capybara.javascript_driver = :screenshots
    end

    config.before(:each, type: :feature) do |example|
      # Same data for an example on every run, whatever the spec order.
      seed = Zlib.crc32(example.id)
      Faker::Config.random = Random.new(seed)
      srand(seed)
      FactoryBot.rewind_sequences
      # factories build short titles and codes from SecureRandom, which shows up on pages
      allow(SecureRandom).to receive(:urlsafe_base64) { |n = 16| Faker::Alphanumeric.alphanumeric(number: n) }
      Timecop.freeze(Screenshots::FROZEN_TIME)
      Screenshots.recorder = Screenshots::Recorder.new(example)
    end

    config.after(:each, type: :feature) do |example|
      if example.exception
        Screenshots.recorder&.discard
        # start the next example in a fresh browser, in case this one broke it
        page.quit
      else
        Screenshots.capture(page)
      end
      Screenshots.recorder = nil
      Timecop.return
    end
  end
end
