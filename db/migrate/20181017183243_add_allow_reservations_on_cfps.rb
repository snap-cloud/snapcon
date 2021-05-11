# frozen_string_literal: true

class AddAllowReservationsOnCfps < ActiveRecord::Migration[5.0]
  def change
    add_column 'cfps', 'enable_registrations', :boolean, default: false
  end
end
