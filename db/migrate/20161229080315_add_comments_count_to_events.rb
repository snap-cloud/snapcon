# frozen_string_literal: true

class AddCommentsCountToEvents < ActiveRecord::Migration[4.2]
  def change
    add_column :events, :comments_count, :integer, default: 0, null: false

    Event.find_each do |event|
      comments_count = event.comment_threads.count
      unless comments_count.zero?
        event.update_attribute(:comments_count, comments_count)
      end
    end
  end
end
