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
    describe 'validations' do
        before do 
          conference.currency_conversions << create(:currency_conversion)
        end 
        it { is_expected.to validate_numericality_of(:rate).is_greater_than(0) }
        it 'validates uniqness of new currency conversion' do
            is_expected.to validate_uniqueness_of(:from_currency).scoped_to(:to_currency).on(:create)
        end 
    end
end 


        





    