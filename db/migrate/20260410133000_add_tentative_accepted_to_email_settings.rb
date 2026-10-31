class AddTentativeAcceptedToEmailSettings < ActiveRecord::Migration[5.0]
  def change
    add_column :email_settings, :send_on_tentative_accepted, :boolean, default: false
    add_column :email_settings, :tentative_accepted_subject, :string
    add_column :email_settings, :tentative_accepted_body, :text
  end
end
