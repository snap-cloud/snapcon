class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('OSEM_EMAIL_ADDRESS', 'no-reply@osem')
  layout 'email_template'
end
