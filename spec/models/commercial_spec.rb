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

  it 'parses snap url' do
    url = 'https://snap.berkeley.edu/project?username=avi_shor&projectname=stamps'
    transformed_url = Commercial.generate_snap_embed(url)
    expected_url = 'https://snap.berkeley.edu/embed?projectname=stamps&username=avi_shor&showTitle=true&showAuthor=true&editButton=true&pauseButton=true'
    expect(transformed_url).to eq expected_url
  end
end
