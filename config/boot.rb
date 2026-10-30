ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'logger' # Required explicitly for Ruby 3.4+ (Logger moved to bundled gem, no longer auto-loaded)
