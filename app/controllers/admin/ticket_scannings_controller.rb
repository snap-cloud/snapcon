# frozen_string_literal: true

module Admin
  class TicketScanningsController < Admin::BaseController
    before_action :authenticate_user!
    load_resource :physical_ticket, find_by: :token
    skip_authorize_resource only: [:create]

    def create
      if !@physical_ticket && params[:physical_ticket]
        @physical_ticket = PhysicalTicket.find_by(token: params[:physical_ticket][:token])
      end
      @ticket_scanning = TicketScanning.new(physical_ticket: @physical_ticket)
      authorize! :create, @ticket_scanning
      @ticket_scanning.save
      dest_path = conferences_path
      if request.referer&.match?(%r{admin/conferences})
        dest_path = admin_conference_physical_tickets_path(conference_id: @conference.short_title)
      end
      redirect_to dest_path,
                  notice: "Ticket with token #{@physical_ticket.token} successfully scanned."
    end
  end
end
