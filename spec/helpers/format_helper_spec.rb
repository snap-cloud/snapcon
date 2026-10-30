# frozen_string_literal: true

require 'spec_helper'

describe FormatHelper, type: :helper do
  describe 'markdown' do
    it 'returns empty string for nil' do
      expect(markdown(nil)).to eq ''
    end

    it "doesn't render links with unsafe URI schemes" do
      expect(markdown('[a](javascript:b)')).to eq "<p>[a](javascript:b)</p>\n"
    end

    it 'returns HTML for header markdown' do
      expect(markdown('# this is my header')).to eq "<h1>this is my header</h1>\n"
    end

    it 'escapes input HTML' do
      expect(markdown('<em>*a*</em>')).to eq "<p>&lt;em&gt;<em>a</em>&lt;/em&gt;</p>\n"
    end

    it 'removes unallowed elements' do
      skip 'SNAPCON: Markdown formatting rules changed... styles are allowed'
      expect(markdown('<em>*<style>a</style>*</em>')).to eq "<p><em><em>a</em></em></p>\n"
    end

    it 'sets nofollow on links' do
      expect(markdown('[a](https://example.com/)'))
        .to eq "<p><a href=\"https://example.com/\" rel=\"nofollow\">a</a></p>\n"
    end
  end

  describe 'markdown_with_variables' do
    let(:conference) do
      create(:conference, short_title: 'snap21', title: 'SnapCon 2021',
             start_date: Date.new(2021, 7, 12), end_date: Date.new(2021, 7, 16))
    end

    it 'substitutes conference variables and renders markdown' do
      text = 'Welcome to **{conference}**, running {conference_start_date} to {conference_end_date}.'
      result = markdown_with_variables(text, conference, false)
      expect(result).to include('Welcome to <strong>SnapCon 2021</strong>')
      expect(result).to include('2021-07-12')
      expect(result).to include('2021-07-16')
    end

    it 'returns empty string for nil text' do
      expect(markdown_with_variables(nil, conference)).to eq ''
    end

    it 'renders normally when there are no placeholders' do
      text = 'Just a regular description.'
      expect(markdown_with_variables(text, conference, false)).to eq "<p>Just a regular description.</p>\n"
    end

    it 'includes venue when conference has one' do
      conference.venue = create(:venue)
      text = 'Join us at {venue}.'
      result = markdown_with_variables(text, conference, false)
      expect(result).to include(conference.venue.name)
    end
  end
end
