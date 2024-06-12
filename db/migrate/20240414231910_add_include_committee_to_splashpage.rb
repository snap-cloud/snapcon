class AddIncludeCommitteeToSplashpage < ActiveRecord::Migration[7.0]
  def change
    add_column :splashpages, :include_committee, :boolean
  end
end
