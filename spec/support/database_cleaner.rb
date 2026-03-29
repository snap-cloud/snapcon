# frozen_string_literal: true

begin
  require 'database_cleaner/active_record'
rescue LoadError
  require 'database_cleaner'
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    Rails.application.load_seed
  end
end
