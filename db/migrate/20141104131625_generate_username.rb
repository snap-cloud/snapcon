# frozen_string_literal: true

class GenerateUsername < ActiveRecord::Migration
  class TempUser < ActiveRecord::Base
    self.table_name = 'users'
  end

  def change
    TempUser.all.each do |user|
      next unless user.username.blank?

      username = user.email.split('@')[0]
      username += user.id.to_s if TempUser.find_by(username:)
      user.update_attributes(username:)
    end
  end
end
