class AddPresentationModeToEvent < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :presentation_mode, :integer
  end
end
