require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  config.assets.css_compressor = :sass
  config.assets.js_compressor = Uglifier.new(harmony: true)
  config.assets.gzip = true

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Disable view rendering logs.
  config.action_view.logger = nil

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  if ENV["OSEM_REDIS_CACHE_STORE"]
    config.cache_store = :redis_cache_store, {
      url:                ENV["OSEM_REDIS_CACHE_STORE"],
      reconnect_attempts: 1, # Defaults to 0
      error_handler:      lambda do |method:, returning:, exception:|
        # Report errors to Sentry as warnings
        Raven.capture_exception(
          exception,
          level: 'warning',
          tags:  { method: method, returning: returning }
        )
      end
    }
  end

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"
  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Set the detault url for action mailer
  config.action_mailer.default_url_options = { host: (ENV['OSEM_HOSTNAME'] || 'localhost:3000') }

  # Set the smtp configuration of your service provider
  # For further details of each configuration checkout: http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration
  config.action_mailer.smtp_settings = {
    address:              ENV['OSEM_SMTP_ADDRESS'],
    port:                 ENV['OSEM_SMTP_PORT'],
    user_name:            ENV['OSEM_SMTP_USERNAME'],
    password:             ENV['OSEM_SMTP_PASSWORD'],
    authentication:       ENV['OSEM_SMTP_AUTHENTICATION'].try(:to_sym),
    domain:               ENV['OSEM_SMTP_DOMAIN'],
    enable_starttls_auto: ENV['OSEM_SMTP_ENABLE_STARTTLS_AUTO'],
    openssl_verify_mode:  ENV['OSEM_SMTP_OPENSSL_VERIFY_MODE']
  }.compact

  # Set the secret_key_base from the env, if not set by any other means
  config.secret_key_base ||= ENV["SECRET_KEY_BASE"]

  # Mailbot settings
  config.mailbot = {
    ytlf_ticket_id: (ENV['YTLF_TICKET_ID'] || 50),
    bcc_address:    ENV['OSEM_MESSAGE_BCC_ADDRESS']
  }

  config.after_initialize do
    Bullet.enable = false
    Bullet.sentry = false
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end
