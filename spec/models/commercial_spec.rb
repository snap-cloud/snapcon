# frozen_string_literal: true

# == Schema Information
#
# Table name: commercials
#
#  id                  :bigint           not null, primary key
#  commercial_type     :string
#  commercialable_type :string
#  title               :string
#  url                 :string
#  created_at          :datetime
#  updated_at          :datetime
#  commercial_id       :string
#  commercialable_id   :integer
#
require 'spec_helper'

describe Commercial do
  it { is_expected.to validate_presence_of(:url) }

  it 'validates url format' do
    commercial = build(:conference_commercial, url: 'ftp://example.com')
    expect(commercial.valid?).to be false
    expect(commercial.errors['url']).to eq ['is invalid']
  end

  it 'validates url rendering' do
    commercial = build(:conference_commercial)
    expect(commercial.valid?).to be true
  end
end
