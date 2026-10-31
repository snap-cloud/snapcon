# frozen_string_literal: true

# Loads Faker and FactoryBot for the data:* demo rake tasks.
#
# Both gems are in the :demo Bundler group, so production installs them but
# doesn't require them at boot. In development and test they are already
# loaded, and this is a no-op.
module DemoFactories
  def self.load!
    require 'faker'
    require 'factory_bot'
    FactoryBot.find_definitions if FactoryBot.factories.none?
  end
end
