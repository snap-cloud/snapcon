# frozen_string_literal: true

class RegistrationDatatable < AjaxDatatablesRails::ActiveRecord
  extend Forwardable

  def_delegator :@view, :dom_id
  def_delegator :@view, :edit_admin_conference_registration_path
  # def_delegator :@view, :delete_admin_conference_registration_path
  def_delegator :@view, :admin_conference_registration_toggle_attendance_path


  def initialize(params, opts = {})
    @view = opts[:view_context]
    super
  end

  def view_columns
    @view_columns ||= {
      id:                       { source: 'Registration.id', cond: :eq },
      name:                     { source: 'User.name' },
      email:                    { source: 'User.email' },
      accepted_code_of_conduct: { source: 'Registration.accepted_code_of_conduct', searchable: false },
      attended:                 { source: 'Registration.attended', searchable: false },
      ticket_price:             { source: 'TicketPurchase.amount_paid' },
      ticket_type:              { source: 'Ticket.title' },
      actions:                  { source: 'Registration.id', searchable: false, orderable: false }
    }
  end

  private

  def conference
    @conference ||= options[:conference]
  end

  def conference_role_titles(record)
    record.roles.collect do |role|
      role.name.titleize if role.resource == conference
    end.compact
  end

  def registration_ticket(record)
    record.user.tickets.for_registration(conference)
  end

  def registration_ticket_price(record)
    record.user.ticket_purchases.where(ticket: registration_ticket(record)).first.amount_paid
  end

  def data
    records.map do |record|
      {
        id:                       record.id,
        name:                     record.user.name,
        roles:                    conference_role_titles(record.user),
        email:                    record.email,
        accepted_code_of_conduct: !!record.accepted_code_of_conduct, # rubocop:disable Style/DoubleNegation
        ticket_type:              registration_ticket(record).title,
        ticket_price:             registration_ticket_price(record),
        attended:                false,
        edit_url:                 edit_admin_conference_registration_path(conference, record),
        # delete_url:               delete_admin_conference_registration_path(conference, record),
        DT_RowId:                 dom_id(record)
      }
    end
  end

  def get_raw_records # rubocop:disable Naming/AccessorMethodName
    conference.registrations.includes(user: %i[roles tickets ticket_purchases]).references(:users, :roles).distinct
  end

  # override upstream santitation, which converts everything to strings
  def sanitize_data(records)
    records
  end
end
