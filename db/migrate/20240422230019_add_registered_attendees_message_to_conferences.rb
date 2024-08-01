class AddRegisteredAttendeesMessageToConferences < ActiveRecord::Migration[7.0]
  def change
    add_column :conferences, :registered_attendees_message, :text
  end
end
