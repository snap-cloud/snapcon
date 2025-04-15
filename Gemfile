# frozen_string_literal: true

def next?
  File.basename(__FILE__) == 'Gemfile.next'
end

source 'https://rubygems.org'

ruby file: '.tool-versions'

# as web framework
if next?
  gem 'rails', '~> 7'
else
  gem 'rails', '~> 7.0'
end

# Use Puma as the app server
gem 'puma'

# respond_to methods have been extracted to the responders gem
# http://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#responders
gem 'responders', '~> 3.0'

# as database
gem 'pg'

# for tracking data changes
gem 'paper_trail', '< 13'

# for upload management
gem 'carrierwave', '< 3'
gem 'carrierwave-bombshelter'
gem 'mini_magick'
# for uploading images to the cloud
gem 'cloudinary'

# for internationalizing
gem 'rails-i18n'

# as authentification framework
gem 'devise'
gem 'devise_ichain_authenticatable'

gem 'omniauth'
gem 'omniauth-discourse', github: 'snap-cloud/omniauth-discourse'
gem 'omniauth-facebook'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'
gem 'omniauth-openid'
gem 'omniauth-rails_csrf_protection'

# Bot-filtering
gem 'recaptcha', require: 'recaptcha/rails'

# as authorization framework
gem 'cancancan'

# for roles
gem 'rolify'

# to show flash messages from ajax requests
gem 'unobtrusive_flash', '>=3'

# as state machine
gem 'transitions', require: %w[transitions active_record/transitions]

# for comments
gem 'acts_as_commentable_with_threading'
gem 'awesome_nested_set'

# as templating language
gem 'haml-rails'

# for stylesheets
gem 'sass-rails', '>= 4.0.2'

# as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# as the front-end framework
gem 'autoprefixer-rails'
gem 'bootstrap-sass', '~> 3.4.0'
gem 'cocoon'

# as the JavaScript library
# TODO: Consolidate with the rails-assets below or move to webpack...
gem 'jquery-rails'
gem 'jquery-ui-rails', '~> 7.0.0'

# for languages validation
gem 'iso-639'

# data tables
gem 'ajax-datatables-rails'
gem 'jquery-datatables'

# for charts
gem 'chartkick'

# for displaying maps
gem 'leaflet-rails'

# for user avatars
gem 'gravtastic'

# for country selects
# TODO-SNAPCON: Verify that this is no longer necessary.
# gem 'country_select', '< 7'
gem 'i18n_data'

# as PDF generator
gem 'prawn-qrcode'
gem 'prawn-rails'
# FIXME: for prawn, matrix isn't in the default set of Ruby 3.1 anymore
# see https://github.com/prawnpdf/prawn/commit/3658d5125c3b20eb11484c3b039ca6b89dc7d1b7
gem 'matrix', '~> 0.4'

# FIXME: for selenium-webdriver, rexml isn't in the default set of Ruby 3.1 anymore
# see https://github.com/SeleniumHQ/selenium/commit/526fd9d0de60a53746ffa982feab985fed09a278
gem 'rexml'

# for QR code generation
gem 'rqrcode'

# to render XLS spreadsheets
gem 'caxlsx_rails'

# Application Monitoring
gem 'sentry-delayed_job'
gem 'sentry-rails'
gem 'sentry-ruby'

# to make links faster
gem 'turbolinks'

# for JSON serialization of our API
gem 'active_model_serializers'

# as icon font
gem 'font-awesome-sass'

# for markdown
gem 'redcarpet'

# for recurring jobs
gem 'delayed_job_active_record'
gem 'whenever', require: false

# to run scripts
gem 'daemons'

# to encapsulate money in objects
gem 'money-rails'

# for lists
gem 'acts_as_list'

# for switch checkboxes
gem 'bootstrap-switch-rails', '3.3.3' # Locked pending Bttstrp/bootstrap-switch#707

# for parsing OEmbed data
gem 'ruby-oembed'

# for setting app configuration in the environment
gem 'dotenv-rails'

# configurable toggles for functionality
# https://github.com/mgsnova/feature
gem 'feature'

# For countable.js
gem 'countable-rails'

# Both are not in a group as we use it also for rake data:demo
# for fake data
gem 'faker'
# for seeds
gem 'factory_bot_rails'

# for integrating Stripe payment gateway
gem 'stripe'

# Provides Sprockets implementation for Rails Asset Pipeline
gem 'sprockets-rails'

# for multiple speakers select on proposal/event forms
gem 'selectize-rails'

# n+1 query logging
gem 'bullet'

# memcached binary connector
gem 'dalli', require: false
# Redis Cache
gem 'redis'

# to generate ical files
gem 'icalendar'

# for making external requests easier
gem 'httparty'

# pagination
gem 'pagy', '<4.0'

# to tame logs
gem 'lograge'

group :development do
  # to open mails
  gem 'letter_opener'
  # view mail at /letter_opener/
  gem 'letter_opener_web'
  # as deployment system
  gem 'mina'
  # as debugger on error pages
  gem 'web-console'
  # prepend models with db schema
  gem 'annotate'
end

group :test do
  # as test framework
  gem 'capybara'
  gem 'cucumber-rails', require: false
  gem 'cucumber-rails-training-wheels' # basic imperative step defs like "Then I should see..."
  gem 'database_cleaner'
  gem 'rspec-rails'
  # for measuring test coverage
  gem 'simplecov'
  gem 'simplecov-cobertura'
  # for describing models
  gem 'shoulda-matchers', require: false
  # for stubing/mocking models
  gem 'rspec-activemodel-mocks'
  # to freeze time
  gem 'timecop'
  # for mocking external requests
  gem 'webmock'
  # for mocking Stripe responses in tests
  gem 'stripe-ruby-mock', '~> 3.1.0.rc3'
  # For validating JSON schemas
  gem 'json-schema'
  # For using 'assigns' in tests
  gem 'rails-controller-testing'
  # For managing the environment
  gem 'climate_control'
  # For PDFs
  gem 'pdf-inspector', require: 'pdf/inspector'
end

group :development, :test, :linters do
  # for static code analisys
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-performance', require: false
  gem 'haml_lint'
  # TODO-SNAPCON: Why is this in the current group?
  gem 'faraday-retry', require: false

  # Easily run linters
  gem 'pronto', require: false
  gem 'pronto-haml', require: false
  gem 'pronto-rubocop', require: false
end

group :development, :test do
  # as capybara driver
  gem 'webdrivers'
  gem 'geckodriver-helper'
  # as debugger
  gem 'byebug'
  # to test new rails version
  gem 'next_rails'
end
