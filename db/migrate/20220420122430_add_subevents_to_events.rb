class AddSubeventsToEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :events, :superevent, :boolean
    add_column :events, :parent_id, :integer
    add_foreign_key :events, :events, column: :parent_id
  end
end
