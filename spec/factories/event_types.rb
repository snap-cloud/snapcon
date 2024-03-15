# frozen_string_literal: true

# == Schema Information
#
# Table name: event_types
#
#  id                      :bigint           not null, primary key
#  color                   :string
#  description             :string
#  length                  :integer          default(30)
#  maximum_abstract_length :integer          default(500)
#  minimum_abstract_length :integer          default(0)
#  submission_template     :text
#  title                   :string           not null
#  created_at              :datetime
#  updated_at              :datetime
#  program_id              :integer
#

FactoryBot.define do
  factory :event_type do
    title { 'Example Event Type' }
    length { 30 }
    description { 'Example Event Description\nThis event type is an example.' }
    minimum_abstract_length { 0 }
    maximum_abstract_length { 500 }
    submission_template { 'Example Event Instructions _with_ **markdown**' }
    color { '#ffffff' }
    program
  end
end
