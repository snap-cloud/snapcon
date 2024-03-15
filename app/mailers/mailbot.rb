# frozen_string_literal: true

YTLF_TICKET_ID = Rails.configuration.mailbot[:ytlf_ticket_id]

class Mailbot < ApplicationMailer
  helper ApplicationHelper
  helper ConferenceHelper

  default bcc:           Rails.configuration.mailbot[:bcc_address],
          template_name: 'email_template',
          content_type:  'text/html',
          to:            -> { @user.email },
          from:          -> { @conference.contact.email }

  def registration_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.registration_body)

    mail(subject: @conference.email_settings.registration_subject)
  end

  def ticket_confirmation_mail(ticket_purchase)
    @ticket_purchase = ticket_purchase
    @user = ticket_purchase.user
    @conference = ticket_purchase.conference

    PhysicalTicket.last(ticket_purchase.quantity).each do |physical_ticket|
      pdf = TicketPdf.new(@conference, @user, physical_ticket, @conference.ticket_layout.to_sym,
                          "ticket_for_#{@conference.short_title}_#{physical_ticket.id}")
      attachments["ticket_for_#{@conference.short_title}_#{physical_ticket.id}.pdf"] = pdf.render
    end

    if @ticket_purchase.ticket_id == YTLF_TICKET_ID
      template_name = 'young_thinkers_ticket_confirmation_template'
      mail(subject: "#{@conference.title} | Ticket Confirmation and PDF!", template_name: template_name)
    end

    # if email subject is empty, use custom template
    if @ticket_purchase.ticket.email_subject.empty? && !@ticket_purchase.ticket.email_body.empty?
      @ticket_purchase.ticket.email_body = @ticket_purchase.generate_confirmation_mail(@ticket_purchase.ticket.email_body)
      mail(subject: "#{@conference.title} | Ticket Confirmation and PDF!", template_name: 'custom_ticket_confirmation_template')
    # if email body is empty, use default template with subject
    elsif !@ticket_purchase.ticket.email_subject.empty? && @ticket_purchase.ticket.email_body.empty?
      @ticket_purchase.ticket.email_subject = @ticket_purchase.generate_confirmation_mail(@ticket_purchase.ticket.email_subject)
      mail(subject: @ticket_purchase.ticket.email_subject, template_name: 'ticket_confirmation_template')
    # if both exist, use custom
    elsif !@ticket_purchase.ticket.email_subject.empty? && !@ticket_purchase.ticket.email_body.empty?
      @ticket_purchase.ticket.email_body = @ticket_purchase.generate_confirmation_mail(@ticket_purchase.ticket.email_body)
      @ticket_purchase.ticket.email_subject = @ticket_purchase.generate_confirmation_mail(@ticket_purchase.ticket.email_subject)
      mail(subject: @ticket_purchase.ticket.email_subject, template_name: 'custom_ticket_confirmation_template')
    # if both empty, use default
    else
      mail(subject: "#{@conference.title} | Ticket Confirmation and PDF!", template_name: 'ticket_confirmation_template')
    end
  end

  def acceptance_mail(event)
    @user = event.submitter
    @conference = event.program.conference
    @speakers = event.speakers.map(&:email)
    @email_body = @conference.email_settings.generate_event_mail(event, @conference.email_settings.accepted_body)

    mail(subject: @conference.email_settings.accepted_subject, cc: @speakers)
  end

  def submitted_proposal_mail(event)
    @user = event.submitter
    @speakers = event.speakers.map(&:email)
    @conference = event.program.conference
    @email_body = @conference.email_settings.generate_event_mail(event,
                                                                 @conference.email_settings.submitted_proposal_body)

    mail(subject: @conference.email_settings.submitted_proposal_subject, cc: @speakers)
  end

  def rejection_mail(event)
    @user = event.submitter
    @speakers = event.speakers.map(&:email)
    @conference = event.program.conference
    @email_body = @conference.email_settings.generate_event_mail(event, @conference.email_settings.rejected_body)

    mail(subject: @conference.email_settings.rejected_subject, cc: @speakers)
  end

  def confirm_reminder_mail(event, user: nil)
    @user = user || event.submitter
    @conference = event.program.conference
    @email_body = @conference.email_settings.generate_event_mail(event,
                                                                 @conference.email_settings.confirmed_without_registration_body)

    mail(subject: @conference.email_settings.confirmed_without_registration_subject)
  end

  def conference_date_update_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.conference_dates_updated_body)

    mail(subject: @conference.email_settings.conference_dates_updated_subject)
  end

  def conference_registration_date_update_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.conference_registration_dates_updated_body)

    mail(subject: @conference.email_settings.conference_registration_dates_updated_subject)
  end

  def conference_venue_update_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.venue_updated_body)

    mail(subject: @conference.email_settings.venue_updated_subject)
  end

  def conference_schedule_update_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.program_schedule_public_body)

    mail(bcc:     nil,
         subject: @conference.email_settings.program_schedule_public_subject)
  end

  def conference_cfp_update_mail(conference, user)
    @user = user
    @conference = conference
    @email_body = @conference.email_settings.generate_email_on_conf_updates(@conference, @user,
                                                                            @conference.email_settings.cfp_dates_updated_body)

    mail(bcc:     nil,
         subject: @conference.email_settings.cfp_dates_updated_subject)
  end

  def conference_booths_acceptance_mail(booth)
    @user = booth.submitter
    @conference = booth.conference
    @email_body = @conference.email_settings.generate_booth_mail(booth,
                                                                 @conference.email_settings.booths_acceptance_body)

    mail(bcc:     nil,
         subject: @conference.email_settings.booths_acceptance_subject)
  end

  def conference_booths_rejection_mail(booth)
    @user = booth.submitter
    @conference = booth.conference
    @email_body = @conference.email_settings.generate_booth_mail(booth,
                                                                 @conference.email_settings.booths_rejection_body)

    mail(bcc:     nil,
         subject: @conference.email_settings.booths_rejection_subject)
  end

  def event_comment_mail(comment, user)
    @comment = comment
    @event = @comment.commentable
    @conference = @event.program.conference
    @user = user

    mail(bcc:           nil,
         template_name: 'comment_template',
         subject:       "New comment has been posted for #{@event.title}")
  end
end
