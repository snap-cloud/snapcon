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
class Commercial < ApplicationRecord
  require 'oembed'
  require_relative '../lib/embeddable_url'

  belongs_to :commercialable, polymorphic: true, touch: true

  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  validates :url, presence: true, uniqueness: { scope: :commercialable }
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[https])

  validate :valid_url

  def self.render_from_url(url)
    register_provider
    begin
      resource = OEmbed::Providers.get(url, maxwidth: 560, maxheight: 315)
      { html: resource.html.html_safe }
    rescue StandardError
      { html: EmbeddableURL.new(url).render_embed.html_safe }
      # { error: exception.message }
    end
  end

  def self.read_file(file)
    require 'csv'
    errors = {}
    errors[:no_event] = []
    errors[:validation_errors] = []

    # parse file as a CSV with a header of id, title, url
    CSV.parse(file, headers: true) do |row|
      id = row['id'].to_i
      title = row['title']
      url = row['url']
      event = Event.find_by(id: id)

      # Go to next event, if the event is not found
      (errors[:no_event] << id) && next unless event

      commercial = event.commercials.new(url: url, title: title)
      unless commercial.save
        errors[:validation_errors] <<
          "Could not create materials for event with ID #{event.id} (#{commercial.errors.full_messages.to_sentence})"
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
