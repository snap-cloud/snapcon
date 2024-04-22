# frozen_string_literal: true

# == Schema Information
#
# Table name: commercials
#
#  id                  :bigint           not null, primary key
#  commercial_type     :string
#  commercialable_type :string
#  title               :string
#  url                 :string
#  created_at          :datetime
#  updated_at          :datetime
#  commercial_id       :string
#  commercialable_id   :integer
#
require 'csv'

class Commercial < ApplicationRecord
  require 'oembed'

  belongs_to :commercialable, polymorphic: true, touch: true

  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  validates :url, presence: true, uniqueness: { scope: :commercialable }
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[https])

  validate :valid_url

  def self.render_from_url(url)
    register_provider
    url = generate_snap_embed(url)
    begin
      resource = OEmbed::Providers.get(url, maxwidth: 560, maxheight: 315)
      { html: resource.html.html_safe }
    rescue StandardError
      { html: iframe_fallback(url) }
      # { error: exception.message }
    end
  end

  def self.generate_snap_embed(url)
    uri = URI.parse(url)
    if uri.host == 'snap.berkeley.edu' && uri.path == '/project'
      args = URI.decode_www_form(uri.query).to_h
    else
      return url
    end
    if args.key?('username') && args.key?('projectname')
      new_query = URI.encode_www_form({
                                        'projectname' => args['projectname'],
                                        'username'    => args['username'],
                                        'showTitle'   => 'true',
                                        'showAuthor'  => 'true',
                                        'editButton'  => 'true',
                                        'pauseButton' => 'true'
                                      })
      new_uri = URI::HTTPS.build(
        host:  uri.host,
        path:  '/embed',
        query: new_query
      )
      return new_uri.to_s
    end
    url
  end

  def self.iframe_fallback(url)
    "<iframe width=560 height=315 frameborder=0 allowfullscreen=true src=\"#{url}\"></iframe>".html_safe
  end

  def self.read_file(file)
    errors = {}
    errors[:no_event] = []
    errors[:validation_errors] = []

    # Check if the file has a .csv extension
    unless File.extname(file.original_filename).casecmp('.csv').zero?
      errors[:validation_errors] << 'File must be a CSV.'
      return errors
    end

    CSV.foreach(file.path, headers: true) do |row|
      # You can access columns by their names if headers are included in the file
      id = row['Event_ID'].to_i
      title = row['Title']
      url = row['URL']

      event = Event.find_by(id: id)

      # Go to next event if the event is not found
      (errors[:no_event] << id) && next unless event

      commercial = event.commercials.new(title: title, url: url)
      unless commercial.save
        errors[:validation_errors] << ("Could not create materials for event with ID #{event.id} (" + commercial.errors.full_messages.to_sentence + ')')
      end
    end
    errors
  end

  private

  def valid_url
    result = Commercial.render_from_url(url)
    errors.add(:base, result[:error]) if result[:error]
  end

  def self.register_provider
    speakerdeck = OEmbed::Provider.new('http://speakerdeck.com/oembed.json')
    speakerdeck << 'https://speakerdeck.com/*'
    speakerdeck << 'http://speakerdeck.com/*'

    OEmbed::Providers.register(
      OEmbed::Providers::Youtube,
      OEmbed::Providers::Vimeo,
      OEmbed::Providers::Slideshare,
      OEmbed::Providers::Flickr,
      OEmbed::Providers::Instagram,
      speakerdeck
    )
    # OEmbed::Providers.register_fallback(
    #   OEmbed::ProviderDiscovery,
    #   OEmbed::Providers::Noembed
    # )
  end

  def conference_id
    case commercialable_type
    when 'Conference' then commercialable_id
    when 'Event' then Event.find(commercialable_id).program.conference_id
    when 'Venue' then Venue.find(commercialable_id).conference_id
    end
  end
end
