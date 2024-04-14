# frozen_string_literal: true

# == Schema Information
#
# Table name: currency_conversions
#
#  id            :bigint           not null, primary key
#  from_currency :string
#  rate          :decimal(, )
#  to_currency   :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  conference_id :bigint           not null
#
# Indexes
#
#  index_currency_conversions_on_conference_id  (conference_id)
#
# Foreign Keys
#
#  fk_rails_...  (conference_id => conferences.id)
#
require 'spec_helper'

describe CurrencyConversion do
  let!(:conference) { create(:conference, title: 'ExampleCon') }
  let(:amount) { Money.from_amount(10.00, 'USD') }

  describe 'validations' do
    before do
      conference.currency_conversions << create(:currency_conversion)
    end

    it { is_expected.to validate_numericality_of(:rate).is_greater_than(0) }

    it { is_expected.to validate_uniqueness_of(:from_currency).scoped_to(:to_currency).on(:create) }
  end

  describe 'convert currency functionality' do
    context 'when conversion rate exists' do
      before do
        conference.currency_conversions << create(:currency_conversion, from_currency: 'USD', to_currency: 'EUR', rate: 0.89)
        conference.currency_conversions << create(:currency_conversion, from_currency: 'USD', to_currency: 'GBP', rate: 0.75)
      end

      it 'converts currency using existing rate' do
        converted_amount = described_class.convert_currency(conference, amount, 'USD', 'EUR')
        expect(converted_amount.currency).to eq('EUR')
        expect(converted_amount.cents).to eq(890)
      end
    end

    context 'when conversion rate does not exist' do
      it 'returns the original amount if no conversion is found' do
        original_amount = described_class.convert_currency(conference, amount, 'USD', 'INR')
        expect(original_amount.cents).to eq(-100)
      end
    end
  end
end
