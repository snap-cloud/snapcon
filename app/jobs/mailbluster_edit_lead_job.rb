# frozen_string_literal: true

class MailblusterEditLeadJob < ApplicationJob
  queue_as :default

  def perform(user_id, add_tags: [], remove_tags: [], old_email: nil)
    user = User.find(user_id)
    MailblusterManager.edit_lead(user, add_tags:, remove_tags:, old_email:)
  end
end
