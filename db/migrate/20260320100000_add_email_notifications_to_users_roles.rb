class AddEmailNotificationsToUsersRoles < ActiveRecord::Migration[7.0]
  def change
    add_column :users_roles, :email_notifications, :boolean, default: true, null: false
  end
end
