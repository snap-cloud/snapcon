# frozen_string_literal: true

# == Schema Information
#
# Table name: rooms
#
#  id             :bigint           not null, primary key
#  discussion_url :string
#  guid           :string           not null
#  name           :string           not null
#  order          :integer
#  size           :integer
#  url            :string
#  venue_id       :integer          not null
#
class RoomSerializer < ActiveModel::Serializer
  attributes :guid, :name, :description

  # FIXME: just giving suseconferenceclient something to play with
  def description
    ''
  end
end
