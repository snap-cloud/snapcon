# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  affiliation            :string
#  avatar_content_type    :string
#  avatar_file_name       :string
#  avatar_file_size       :integer
#  avatar_updated_at      :datetime
#  biography              :text
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  default_currency       :string
#  email                  :string           default(""), not null
#  email_public           :boolean          default(FALSE)
#  encrypted_password     :string           default(""), not null
#  is_admin               :boolean          default(FALSE)
#  is_disabled            :boolean          default(FALSE)
#  languages              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  mobile                 :string
#  name                   :string
#  nickname               :string
#  picture                :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0)
#  timezone               :string
#  tshirt                 :string
#  unconfirmed_email      :string
#  username               :string
#  volunteer_experience   :text
#  created_at             :datetime
#  updated_at             :datetime
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_username              (username) UNIQUE
#
class IChainRecordNotFound < StandardError
end

class UserDisabled < StandardError
end

class User < ApplicationRecord
  include TrackSavedChanges

  # prevent N+1 queries with has_cached_role? by preloading roles *always*
  default_scope { preload(:roles) }

  has_many :ticket_purchases, dependent: :destroy
  has_many :physical_tickets, through: :ticket_purchases do
    def by_conference(conference)
      where('ticket_purchases.conference_id = ?', conference)
    end
  end
  has_many :tickets, through: :ticket_purchases, source: :ticket do
    def for_registration(conference)
      where(conference: conference, registration_ticket: true).first
    end
  end

  has_many :users_roles
  rolify
  has_many :roles, through: :users_roles, dependent: :destroy

  has_paper_trail on: %i[create update], ignore: %i[sign_in_count remember_created_at current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip unconfirmed_email
                                                    avatar_content_type avatar_file_size avatar_updated_at updated_at confirmation_sent_at confirmation_token reset_password_token]

  # A user may have an uploaded avatar or use gravatar.
  # The uploaded picture takes precedence.
  include Gravtastic
  gravtastic size: 32

  mount_uploader :picture, PictureUploader, mount_on: :picture

  before_create :setup_role

  after_save :touch_events

  # Note that using after_create_commit and after_update_commit does not work.
  # See https://github.com/CactusPuppy/snapcon/pull/43#discussion_r609458034
  after_commit :mailbluster_create_lead, on: :create
  after_commit :mailbluster_delete_lead, on: :destroy
  after_commit :mailbluster_update_lead, on: :update, if: lambda { |user|
                                                            %w[name email].any? do |key|
                                                              user.ts_saved_changes.key? key
                                                            end
                                                          }

  # add scope
  scope :comment_notifiable, lambda { |conference|
                               joins(:roles).where('roles.name IN (?)', %i[organizer cfp]).where('roles.resource_type = ? AND roles.resource_id = ?', 'Conference', conference.id)
                             }

  # scopes for user distributions
  scope :recent, lambda {
    where('last_sign_in_at > ?', Date.today - 3.months).where(is_disabled: false)
  }
  scope :unconfirmed, -> { where('confirmed_at IS NULL') }
  scope :dead, -> { where(last_sign_in_at: ...(Date.today - 1.year)) }

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise_modules = []

  devise_modules += if ENV.fetch('OSEM_ICHAIN_ENABLED', nil) == 'true'
                      [:ichain_authenticatable, :ichain_registerable, :omniauthable, { omniauth_providers: [] }]
                    else
                      [:database_authenticatable, :registerable,
                       :recoverable, :rememberable, :trackable, :validatable, :confirmable,
                       :omniauthable,
                       { omniauth_providers: %i[suse google facebook github discourse] }]
                      #  omniauth_providers: [:google, :discourse]
                    end

  devise(*devise_modules)

  has_many :openids

  attr_accessor :login

  has_many :event_users, dependent: :destroy
  has_many :events, -> { distinct }, through: :event_users
  has_many :presented_events, lambda {
                                joins(:event_users).where(event_users: { event_role: 'speaker' }).distinct
                              }, through: :event_users, source: :event
  has_many :registrations, dependent: :destroy do
    def for_conference(conference)
      where(conference: conference).first
    end
  end
  has_many :events_registrations, through: :registrations
  has_many :payments, dependent: :destroy

  has_many :votes, dependent: :destroy
  has_many :voted_events, through: :votes, source: :events
  has_many :subscriptions, dependent: :destroy
  has_many :tracks, foreign_key: 'submitter_id'
  has_many :booth_requests, dependent: :destroy
  has_many :booths, through: :booth_requests
  has_many :survey_replies
  has_many :survey_submissions
  has_and_belongs_to_many :favourite_events, class_name: 'Event'

  accepts_nested_attributes_for :roles

  scope :admin, -> { where(is_admin: true) }
  scope :active, lambda {
    where(is_disabled: false)
  }

  validates :email, presence: true

  validates :username,
            uniqueness: {
              case_sensitive: false
            },
            presence:   true

  validate :biography_limit
  validates :affiliation, length: { maximum: 150 }

  DISTRIBUTION_COLORS = {
    'Active'      => 'green',
    'Unconfirmed' => 'red',
    'Dead'        => 'black'
  }.freeze

  ##
  # Checkes if the user attended the event
  # This is used for events that require registration
  # The user must have registered to attend the event
  # Gets an event
  # === Returns
  # * +true+ if the user attended the event
  # * +false+ if the user did not attend the event
  def attended_event?(event)
    event_registration = event.events_registrations.find_by(registration: registrations)

    return false unless event_registration.present?

    event_registration.attended
  end

  def mark_attendance_for_conference(conference)
    registration = registrations.for_conference(conference)
    return true if registration&.attended

    registration.attended = true
    registration.save
  end

  def mark_attendance_for_event(event)
    event_registration = event.events_registrations.find_by(registration: registrations)
    return true if event_registration&.attended

    if event_registration.blank?
      conference_registration = registrations.for_conference(event.conference)
      event_registration = event.events_registrations.build
      event_registration.registration = conference_registration
    end
    event_registration.attended = true
    event_registration.save
  end

  def name
    self[:name].presence || username
  end

  ##
  # Checks if a user has registered to an event
  # ====Returns
  # * +true+ or +false+
  def registered_to_event?(event)
    event.registrations.include? registrations.find_by(conference: event.program.conference)
  end

  def subscribed?(conference)
    subscriptions.find_by(conference_id: conference.id).present?
  end

  def supports?(conference)
    ticket_purchases.find_by(conference_id: conference.id, paid: true).present?
  end

  ##
  # Returns a user's profile picture URL.
  # Partials should *not* directly call `gravatar_url`
  def profile_picture(opts = {})
    return gravatar_url(opts) unless picture.present?

    size = (opts[:size] || 0).to_i
    if size < 50
      picture.tiny.url
    elsif size <= 100
      picture.thumb.url
    else
      picture.large.url
    end
  end

  def self.for_ichain_username(username, attributes)
    user = find_by(username: username)

    raise UserDisabled if user&.is_disabled

    if user
      user.update(email:              attributes[:email],
                  last_sign_in_at:    user.current_sign_in_at,
                  current_sign_in_at: Time.current)
    else
      begin
        user = create!(username: username, email: attributes[:email])
      rescue ActiveRecord::RecordNotUnique
        raise IChainRecordNotFound
      end
    end
    user
  end

  ##
  # Returns a hash with user distribution => {value: count of user state, color: color}
  # active: signed in during the last 3 months
  # unconfirmed: registered but not confirmed
  # dead: not signed in during the last year
  #
  # ====Returns
  # * +hash+ -> hash
  def self.distribution
    {
      'Active'      => User.recent.count,
      'Unconfirmed' => User.unconfirmed.count,
      'Dead'        => User.dead.count
    }
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)
    if login
      where(conditions).where(['lower(username) = :value OR lower(email) = :value', { value: login.downcase }]).first
    else
      where(conditions).first
    end
  end

  # Searches for user based on email. Returns found user or new user.
  # ====Returns
  # * +User::ActiveRecord_Relation+ -> user
  def self.find_for_auth(auth, current_user = nil)
    user = current_user

    if user.nil? # No current user available, user is not already logged in
      user = User.where(email: auth.info.email).first_or_initialize
    end

    if user.new_record?
      user.email = auth.info.email
      user.name = auth.info.name
      user.username = auth.info.username
      user.password = Devise.friendly_token[0, 20]
      user.skip_confirmation!
    end

    user
  end

  # Gets the roles of the user, groups them by role.name and returns the resource(s) of each role
  # ====Returns
  # * +Hash+ * ->  e.g. 'organizer' =>  [conf1, conf2]
  def get_roles
    result = {}
    roles.each do |role|
      resource = if role.resource_type == 'Conference'
                   Conference.find(role.resource_id).short_title
                 elsif role.resource_type == 'Track'
                   Track.find(role.resource_id).name
                 end
      if result[role.name].nil?
        result[role.name] = [resource]
      else
        result[role.name] << resource
      end
    end
    result
  end

  # TODO: Use a real authorization in the right place....
  def manages_volunteers?(conference)
    organizer_roles = get_roles['organizer']
    organizer_roles&.include?(conference.short_title) # TODO: or Volunteer Coorinator.
  end

  def registered
    if registrations.count == 0
      'None'
    else
      registrations.map { |r| r.conference.title }.join ', '
    end
  end

  def attended
    registrations_attended = registrations.where(attended: true)
    if registrations_attended.count == 0
      'None'
    else
      registrations_attended.map { |r| r.conference.title }.join ', '
    end
  end

  def attended_count
    attributes['attended_count'] || registrations.where(attended: true).count
  end

  def confirmed?
    !confirmed_at.nil?
  end

  def proposals(conference)
    events.where('program_id = ? AND (event_users.event_role=? OR event_users.event_role=?)', conference.program.id,
                 'submitter', 'speaker')
  end

  def proposal_count(conference)
    proposals(conference).count
  end

  def volunteer_duties(conference)
    events.where(program_id: conference.program.id, 'event_users.event_role': 'volunteer')
  end

  def count_registration_tickets(conference)
    count = 0
    ticket_purchases.by_conference(conference).each do |ticket_purchase|
      count += 1 if ticket_purchase.ticket.registration_ticket
    end

    count
  end

  def self.empty?
    User.count == 1 && User.first.email == 'deleted@localhost.osem'
  end

  def dropdwon_display
    more_info = email_public? ? username : "#{username} #{email}"
    "#{name} (#{more_info})"
  end

  private

  def setup_role
    self.is_admin = true if User.empty?
  end

  def mailbluster_create_lead
    MailblusterCreateLeadJob.perform_later(id)
    ts_reset_saved_changes
  end

  def mailbluster_delete_lead
    MailblusterDeleteLeadJob.perform_later(email)
    ts_reset_saved_changes
  end

  def mailbluster_update_lead
    MailblusterEditLeadJob.perform_later(id, old_email: ts_saved_changes.fetch('email', [nil])[0])
    ts_reset_saved_changes
  end

  def touch_events
    event_users.each(&:touch)
  end

  ##
  # Check if biography has an allowed number of words. Used as validation.
  #
  def biography_limit
    errors.add(:biography, 'is limited to 200 words.') if biography.present? && (biography.split.length > 200)
  end

  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end
end
