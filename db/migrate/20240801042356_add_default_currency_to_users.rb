class AddDefaultCurrencyToUsers < ActiveRecord::Migration[7.0]
  def change
    unless ActiveRecord::Base.connection.column_exists?(:users, :default_currency)
      add_column :users, :default_currency, :text
    end
  end
end
