class AddTitleToCommercials < ActiveRecord::Migration[5.2]
  def change
    add_column :commercials, :title, :string
  end
end
