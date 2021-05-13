# frozen_string_literal: true

class MailblusterDeleteLeadJob < ApplicationJob
  queue_as :default

  def perform(user)
    MailblusterManager.delete_lead(user)
  end
end
