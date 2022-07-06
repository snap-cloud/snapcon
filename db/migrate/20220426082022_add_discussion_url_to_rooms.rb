class AddDiscussionUrlToRooms < ActiveRecord::Migration[5.2]
   def change
     add_column :rooms, :discussion_url, :string
   end
 end
