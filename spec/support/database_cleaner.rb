# frozen_string_literal: true

require 'database_cleaner/active_record' rescue require 'database_cleaner'
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    Rails.application.load_seed
  end
end
