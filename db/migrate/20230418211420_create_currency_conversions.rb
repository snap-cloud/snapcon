class CreateCurrencyConversions < ActiveRecord::Migration[7.0]
  def change
    create_table :currency_conversions, if_not_exists: true do |t|
      t.decimal :rate
      t.string :from_currency
      t.string :to_currency
      t.references :conference, null: false, foreign_key: true

      t.timestamps
    end
  end
end
