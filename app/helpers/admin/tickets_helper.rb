module Admin
  module TicketsHelper
    def default_ticket_email_template
      {
        subject_input_id: 'ticket_email_subject',
        subject_text:     '{conference} | Ticket Confirmation and PDF!',
        body_input_id:    'ticket_email_body',
        body_text:        "Dear {name},\n\nThanks! You have successfully booked {ticket_quantity} {ticket_title}
ticket(s) for the event {conference}. Your transaction id is {ticket_purchase_id}.\nPlease,
find the ticket(s) pdf attached.\n\nBest wishes,\n{conference} Team"
      }
    end
  end
end
