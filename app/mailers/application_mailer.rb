class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('OSEM_EMAIL_ADDRESS')
  layout 'email_template'
end
