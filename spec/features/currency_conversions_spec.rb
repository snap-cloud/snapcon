# frozen_string_literal: true

require 'spec_helper'

describe CurrencyConversion do
  let!(:conference) { create(:conference, title: 'ExampleCon') }
  let!(:admin) { create(:admin) }

  context 'as an admin' do
    before do
      sign_in admin
    end

    after do
      sign_out
    end

    context 'for a conference with no tickets' do
      before do 
        conference.currency_conversions << create(:currency_conversion)
        conference.tickets.destroy_all
      end 

      it 'show error message when adding new currency conversion', feature: true, js: true do
        visit admin_conference_currency_conversions_path(conference.short_title)
        click_link 'Add Currency Conversion'
        page.find('#flash')
        expect(flash).to eq('No tickets available for this conference. Cannot create or edit currency conversions.')
      end 

      it 'show error message when editing a currency conversion', feature: true, js: true do
        visit admin_conference_currency_conversions_path(conference.short_title)
        within('table tbody tr:nth-of-type(1) td:nth-of-type(4)') do
          click_link 'Edit'
        end
        page.find('#flash')
        expect(flash).to eq('No tickets available for this conference. Cannot create or edit currency conversions.')
      end 

      it 'does not show error message when deleting a currency conversion', feature: true, js: true do
        visit admin_conference_currency_conversions_path(conference.short_title)
        page.accept_alert do
          within('table tbody tr:nth-of-type(1) td:nth-of-type(4)') do
            click_link 'Delete'
          end
        end
        page.find('#flash')
        expect(flash).to eq('Currency conversion was successfully deleted.')
        within('table#currency-conversions') do
          expect(page.assert_selector('tbody tr', count: 0)).to be true
        end
      end
    end 
    
    context 'for a conference with tickets' do 
    
      it 'add a currency conversion', feature: true, js: true do
        visit admin_conference_currency_conversions_path(conference.short_title)
        click_link 'Add Currency Conversion'
        select 'EUR', from: 'currency_conversion_to_currency'
        fill_in 'currency_conversion_rate', with: '0.89'
        click_button 'Create Currency conversion'
        page.find('#flash')
        expect(flash).to eq('Currency conversion was successfully created.')
        within('table#currency-conversions') do
          expect(page.has_content?('USD')).to be true
          expect(page.has_content?('EUR')).to be true
          expect(page.has_content?('0.89')).to be true
          expect(page.assert_selector('tbody tr', count: 1)).to be true
        end
      end

      it 'edit a currency conversion', feature: true, js: true do
        conference.currency_conversions << create(:currency_conversion)
        visit admin_conference_currency_conversions_path(conference.short_title)
        within('table tbody tr:nth-of-type(1) td:nth-of-type(4)') do
          click_link 'Edit'
        end
        select 'JPY', from: 'currency_conversion_to_currency'
        fill_in 'currency_conversion_rate', with: '6.9'
        click_button 'Update Currency conversion'
        page.find('#flash')
        expect(flash).to eq('Currency conversion was successfully updated.')
        within('table#currency-conversions') do
          expect(page.has_content?('USD')).to be true
          expect(page.has_content?('JPY')).to be true
          expect(page.has_content?('6.9')).to be true
          expect(page.assert_selector('tbody tr', count: 1)).to be true
        end
      end

      it 'Deletes Currency Conversion', feature: true, js: true do
        conference.currency_conversions << create(:currency_conversion)
        visit admin_conference_currency_conversions_path(conference.short_title)
        # Remove currency conversion
        page.accept_alert do
          within('table tbody tr:nth-of-type(1) td:nth-of-type(4)') do
            click_link 'Delete'
          end
        end
        page.find('#flash')

        # Validations
        expect(flash).to eq('Currency conversion was successfully deleted.')
        within('table#currency-conversions') do
          expect(page.assert_selector('tbody tr', count: 0)).to be true
        end
      end
    end 
  end
end
