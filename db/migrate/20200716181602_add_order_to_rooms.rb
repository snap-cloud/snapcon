# frozen_string_literal: true

class AddOrderToRooms < ActiveRecord::Migration[5.2]
  def change
    add_column :rooms, :order, :int
  end
end
