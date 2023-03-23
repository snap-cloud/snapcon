class AddEmailSubjectToTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :tickets, :email_subject, :string
  end
end
