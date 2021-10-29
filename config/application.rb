require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Osem
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0

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

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Set cache headers
    config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=31536000' }

    config.active_job.queue_adapter = :delayed_job

    config.conference = {
      events_per_page:       (ENV['EVENTS_PER_PAGE'] || 3),
      default_logo_filename: (ENV['DEFAULT_LOGO_FILENAME'] || 'snapcon_logo.png'),
      default_color:         (ENV['DEFAULT_COLOR'] || '#0B3559')
    }

    # Before Moving to Webpack, you can add assets to package.json
    config.assets.paths << Rails.root.join('node_modules')

    config.fullcalendar = {
      license_key: ENV['FULL_CALENDAR_LICENSE_KEY']
    }
    config.active_record.sqlite3.represent_boolean_as_integer = false
    # Require `belongs_to` associations by default. Previous versions had false.
    config.active_record.belongs_to_required_by_default = false
  end
end
