class AddEmailBodyToTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :tickets, :email_body, :text
  end
end
