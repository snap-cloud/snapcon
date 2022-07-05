class FixTimeZone < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :timezome, :timezone
  end
end
