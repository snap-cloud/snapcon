# frozen_string_literal: true

class MailblusterCreateLeadJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    MailblusterManager.create_lead(User.find(user_id))
  end
end
