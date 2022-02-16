# == Schema Information
#
# Table name: events_users
#
#  event_id :bigint
#  user_id  :bigint
#
# Indexes
#
#  index_events_users_on_event_id  (event_id)
#  index_events_users_on_user_id   (user_id)
#
class FavouriteEvents < ApplicationRecord
  self.table_name = 'events_users'
end
