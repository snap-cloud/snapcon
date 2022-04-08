# frozen_string_literal: true

# == Schema Information
#
# Table name: schedules
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  program_id :integer
#  track_id   :integer
#
# Indexes
#
#  index_schedules_on_program_id  (program_id)
#  index_schedules_on_track_id    (track_id)
#
class Schedule < ApplicationRecord
  belongs_to :program, touch: true
  belongs_to :track
  has_many :event_schedules, dependent: :destroy
  has_many :events, through: :event_schedules

  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  def with_all_associated_data
    includes(event_schedule: { event: [:event_type] })
  end

  # TODO: User this or remove.
  # A user's schedule includes:
  # favorited events
  # events speaking at
  # volunteer events.
  def for_user(user)
    events.select { |event| event.planned_for_user?(user) }
  end

  private

  def conference_id
    program.conference_id
  end
end
