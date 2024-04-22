# frozen_string_literal: true

# == Schema Information
#
# Table name: tickets
#
#  id                  :bigint           not null, primary key
#  description         :text
#  email_body          :text
#  email_subject       :string
#  price_cents         :integer          default(0), not null
#  price_currency      :string           default("USD"), not null
#  registration_ticket :boolean          default(FALSE)
#  title               :string           not null
#  visible             :boolean          default(TRUE)
#  created_at          :datetime
#  updated_at          :datetime
#  conference_id       :integer
#
require 'spec_helper'

describe Ticket do
  let(:conference) { create(:conference) }
  let(:ticket) { create(:ticket, price: 50, price_currency: 'USD', conference: conference) }
  let(:user) { create(:user) }

  describe 'validation' do
    it 'is not valid without a title' do
      expect(subject).to validate_presence_of(:title)
    end

    it 'is not valid without a price_cents' do
      expect(subject).to validate_presence_of(:price_cents)
    end

    it 'is not valid without a price_currency' do
      expect(subject).to validate_presence_of(:price_currency)
    end

    it 'is not valid with a price_cents smaller than zero' do
      expect(subject).not_to allow_value(-1).for(:price_cents)
    end

    it 'is valid with a price_cents equals zero' do
      expect(subject).to allow_value(0).for(:price_cents)
    end

    it 'is valid with a price_cents greater than zero' do
      expect(subject).to allow_value(1).for(:price_cents)
    end

    it 'is not valid if tickets of conference do not have same currency' do
      conflicting_currency_ticket = build(:ticket,
                                          conference:     ticket.conference,
                                          price_currency: 'INR')
      expected_error_message = 'Price currency is different from the existing tickets of this conference.'

      expect(conflicting_currency_ticket).not_to be_valid
      expect(conflicting_currency_ticket.errors.full_messages).to eq([expected_error_message])
    end
  end

  describe 'association' do
    it { is_expected.to belong_to(:conference) }
    it { is_expected.to have_many(:ticket_purchases).dependent(:destroy) }
    it { is_expected.to have_many(:buyers).through(:ticket_purchases).source(:user) }
  end

  describe '#bought?' do
    it 'returns true if the user has bought this ticket' do
      create(:ticket_purchase,
             user:   user,
             ticket: ticket)
      expect(ticket.bought?(user)).to be(true)
    end

    it 'returns false if the user has not bought this ticket' do
      expect(ticket.bought?(user)).to be(false)
    end
  end

  describe '#tickets_turnover_total' do
    subject { ticket.tickets_turnover_total ticket.id }

    let!(:purchase1) do
      create(:ticket_purchase, ticket: ticket, amount_paid: 5_000, amount_paid_cents: 500_000, quantity: 1, currency: 'USD', paid: true, user: user)
    end
    let!(:purchase2) do
      create(:ticket_purchase, ticket: ticket, amount_paid: 5_000, amount_paid_cents: 500_000, quantity: 2, currency: 'USD', paid: true, user: user)
    end
    let!(:purchase3) do
      create(:ticket_purchase, ticket: ticket, amount_paid: 5_000, amount_paid_cents: 500_000, quantity: 10, currency: 'USD', paid: false, user: user)
    end

    it 'returns turnover as Money with ticket\'s currency' do
      expect(subject).to eq Money.new(500_000 * 3, ticket.price_currency)
    end
  end

  describe '#unpaid?' do
    let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket) }

    context 'user has not paid' do
      it 'returns true' do
        expect(ticket.unpaid?(user)).to be(true)
      end
    end

    context 'user has paid' do
      before { ticket_purchase.update_attribute(:paid, true) }

      it 'returns false' do
        expect(ticket.unpaid?(user)).to be(false)
      end
    end
  end

  describe '#tickets_paid' do
    before do
      create(:ticket_purchase, user: user, ticket: ticket)
      create(:ticket_purchase, user: user, ticket: ticket, paid: true)
    end

    it 'returns correct number of paid/total tickets' do
      expect(ticket.tickets_paid(user)).to eq('10/20')
    end
  end

  describe '#quantity_bought_by' do
    context 'user has not paid' do
      it 'returns the correct value if the user has bought this ticket' do
        create(:ticket_purchase,
               user:     user,
               ticket:   ticket,
               quantity: 20)
        expect(ticket.quantity_bought_by(user, paid: false)).to eq(20)
      end

      it 'returns zero if the user has not bought this ticket' do
        expect(ticket.quantity_bought_by(user, paid: false)).to eq(0)
      end
    end

    context 'user has paid' do
      let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket, quantity: 20) }

      before { ticket_purchase.update_attribute(:paid, true) }

      it 'returns the correct value if the user has bought and paid for this ticket' do
        expect(ticket.quantity_bought_by(user, paid: true)).to eq(20)
      end
    end
  end

  describe '#total_price' do
    context 'user has not paid' do
      it 'returns the correct value if the user has bought this ticket' do
        create(:ticket_purchase,
               user:     user,
               ticket:   ticket,
               quantity: 20)
        expect(ticket.total_price(user, paid: false)).to eq(Money.new(100_000, 'USD'))
      end

      it 'returns zero if the user has not bought this ticket' do
        expect(ticket.total_price(user, paid: false)).to eq(Money.new(0, 'USD'))
      end
    end

    context 'user has paid' do
      let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket, quantity: 20) }

      before { ticket_purchase.update_attribute(:paid, true) }

      it 'returns the correct value if the user has bought this ticket' do
        expect(ticket.total_price(user, paid: true)).to eq(Money.new(100_000, 'USD'))
      end
    end
  end

  describe 'self.total_price' do
    let(:diversity_supporter_ticket) { create(:ticket, conference: conference, price: 500) }

    describe 'user has bought' do
      context 'no tickets' do
        it 'returns zero' do
          expect(Ticket.total_price(conference, user, paid: false)).to eq(Money.new(0, 'USD'))
        end
      end

      context 'one type of ticket' do
        before do
          create(:ticket_purchase, ticket: ticket, user: user, quantity: 20)
        end

        it 'returns the correct total price' do
          expect(Ticket.total_price(conference, user, paid: false)).to eq(Money.new(100_000, 'USD'))
        end
      end

      context 'multiple types of tickets' do
        before do
          create(:ticket_purchase, ticket: ticket, user: user, quantity: 20)
          create(:ticket_purchase, ticket: diversity_supporter_ticket, user: user, quantity: 2)
        end

        it 'returns the correct total price' do
          total_price = Money.new(200_000, 'USD')
          expect(Ticket.total_price(conference, user, paid: false)).to eq(total_price)
        end
      end
    end
  end

  describe 'currency updation' do
    context 'when more than one ticket exist for a conference' do
      it 'does not allow currency update' do
        ticket.update(price_currency: 'INR')
        expected_error_message = 'Price currency is different from the existing tickets of this conference.'
        expect(ticket.errors.full_messages).to eq([expected_error_message])
      end
    end

    context 'when a single ticket exists for a conference' do
      before do
        ticket.destroy
      end

      it 'allows currency update' do
        free_ticket = Ticket.first
        expect { free_ticket.update_attribute(:price_currency, 'INR') }.to change {
                                                                             free_ticket.reload.price_currency
                                                                           }.from('USD').to('INR')
      end
    end
  end
end
