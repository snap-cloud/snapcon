require 'feature'

repo = Feature::Repository::SimpleRepository.new

# configure features here
repo.add_active_feature :recaptcha unless ENV['RECAPTCHA_SITE_KEY'].blank? || ENV['RECAPTCHA_SECRET_KEY'].blank?

Feature.set_repository repo
