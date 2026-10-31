# frozen_string_literal: true

require 'spec_helper'

describe EmailTemplateParser do
  let(:conference) do
    create(:conference, short_title: 'goto', start_date: Date.new(2014, 5, 1), end_date: Date.new(2014, 5, 6))
  end
  let(:user) { create(:user, username: 'johnd', email: 'john@doe.com', name: 'John Doe') }

  describe '#retrieve_values' do
    context 'without a user' do
      let(:parser) { described_class.new(conference, nil) }

      it 'returns conference values without user values' do
        values = parser.retrieve_values
        expect(values['conference']).to eq conference.title
        expect(values['conference_start_date']).to eq Date.new(2014, 5, 1)
        expect(values['conference_end_date']).to eq Date.new(2014, 5, 6)
        expect(values).not_to have_key('email')
        expect(values).not_to have_key('name')
      end

      it 'includes venue when conference has one' do
        conference.venue = create(:venue)
        values = parser.retrieve_values
        expect(values['venue']).to eq conference.venue.name
        expect(values['venue_address']).to eq conference.venue.address
      end

      it 'includes cfp dates when conference has cfp' do
        create(:cfp, start_date: Date.new(2014, 4, 29), end_date: Date.new(2014, 5, 6),
               program: conference.program)
        values = parser.retrieve_values
        expect(values['cfp_start_date']).to eq Date.new(2014, 4, 29)
        expect(values['cfp_end_date']).to eq Date.new(2014, 5, 6)
      end
    end

    context 'with a user' do
      let(:parser) { described_class.new(conference, user) }

      it 'includes user values' do
        values = parser.retrieve_values
        expect(values['email']).to eq 'john@doe.com'
        expect(values['name']).to eq 'John Doe'
        expect(values['conference']).to eq conference.title
      end
    end
  end

  describe '.parse_template' do
    it 'substitutes conference variables in text' do
      values = { 'conference' => 'SnapCon 2014', 'conference_start_date' => Date.new(2014, 5, 1) }
      text = 'Welcome to {conference}, starting {conference_start_date}!'
      result = described_class.parse_template(text, values)
      expect(result).to eq 'Welcome to SnapCon 2014, starting 2014-05-01!'
    end

    it 'leaves unknown placeholders alone' do
      values = { 'conference' => 'SnapCon 2014' }
      text = 'Welcome to {conference}, dear {name}!'
      result = described_class.parse_template(text, values)
      expect(result).to eq 'Welcome to SnapCon 2014, dear {name}!'
    end
  end
end
