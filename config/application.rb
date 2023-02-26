require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
# require 'active_job/railtie'
require 'active_record/railtie'
# require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require 'action_mailbox/engine'
# require 'action_text/engine'
require 'action_view/railtie'
# require 'action_cable/engine'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Osem
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = ENV.fetch('OSEM_TIME_ZONE') { 'UTC' }
    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    # config.active_record.whitelist_attributes = true

    # Set cache headers
    config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=31536000' }

    config.active_job.queue_adapter = :delayed_job

    config.conference = {
      events_per_page:       ENV.fetch('EVENTS_PER_PAGE', 3),
      default_logo_filename: ENV.fetch('DEFAULT_LOGO_FILENAME', 'snapcon_logo.png'),
      default_color:         ENV.fetch('DEFAULT_COLOR', '#0B3559')
    }

    config.fullcalendar = {
      license_key: ENV.fetch('FULL_CALENDAR_LICENSE_KEY', nil)
    }

    # Don't generate system test files.
    config.generators.system_tests = nil
    # This is a nightmare with our current data model, no one ever thought about this.
    config.active_record.belongs_to_required_by_default = false
  end
end
