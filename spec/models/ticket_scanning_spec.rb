# frozen_string_literal: true

# == Schema Information
#
# Table name: ticket_scannings
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  physical_ticket_id :integer          not null
#
require 'spec_helper'

describe TicketScanning do
  let(:conference) { create(:conference) }
  let(:user) { create(:user) }
  let(:registration) { create(:registration, conference:, user:) }
  let(:registration_ticket) { create(:registration_ticket, conference:) }
  let(:paid_ticket_purchase) do
    create(:paid_ticket_purchase, conference:, user:, ticket: registration_ticket, quantity: 1)
  end
  let(:physical_ticket) { create(:physical_ticket, ticket_purchase: paid_ticket_purchase) }
  let(:ticket_scanning) { create(:ticket_scanning, physical_ticket:) }

  describe 'before_create' do
    it 'marks user as present' do
      expect(registration.attended).to be(false)
      ticket_scanning
      registration.reload
      expect(registration.attended).to be(true)
    end
  end
end
