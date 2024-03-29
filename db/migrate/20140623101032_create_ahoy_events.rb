# frozen_string_literal: true

class CreateAhoyEvents < ActiveRecord::Migration
  def change
    create_table :ahoy_events do |t|
      t.uuid :visit_id
      # user
      t.integer :user_id
      # add t.string :user_type if polymorphic
      t.string :name
      t.text :properties
      t.timestamp :time
    end

    add_index :ahoy_events, :visit_id
    add_index :ahoy_events, :user_id
    add_index :ahoy_events, :time
  end
end
