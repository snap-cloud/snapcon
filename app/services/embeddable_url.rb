# Transform a URL to a version that allows iframes

class EmbeddableURL
  attr_accessor :url

  DEFAULT_FRAME_ATTRS = 'width=560 height=315 frameborder=0 allowfullscreen'.freeze

  TRANSFORMATIONS = {
    /snap\.berkeley\.edu/ => :snap,
    /docs\.google\.com/   => :google_docs,
    /dropbox\.com/        => :dropbox
  }.freeze

  def initialize(url)
    self.url = url
  end

  def render_embed
    return render_dropbox if url.match?(/dropbox\.com/)

    "<iframe #{DEFAULT_FRAME_ATTRS} src='#{iframe_url}'></iframe>"
  end

  def iframe_url
    TRANSFORMATIONS.each do |regex, fn|
      return send(fn, url) if url.match?(regex)
    end
    url
  end

  # TODO: Consider adjusting the id / loading if > 1 dropbox embed per page.
  def render_dropbox
    <<~HTML
      <div>
        <script type="text/javascript" src="https://www.dropbox.com/static/api/2/dropins.js" id="dropboxjs" data-app-key="#{ENV.fetch('DROPBOX_APP_KEY', nil)}"></script>
        <a href="#{url}"
        class="dropbox-embed" data-height="315px" data-width="560px"></a>
      </div>
    HTML
  end

  private

  def optional_params
    return '' unless url.match?(/snap\.berkeley/)

    'allow="geolocation;microphone;camera"'
  end

  def google_docs(url)
    # replace /edit, /share, /comment with /embed and remove the querystring
    url.gsub(%r{(/edit|/share|/comment).*}, '/embed')
  end

  def dropbox(url)
    uri = URI.parse(url)
    query = CGI.parse(uri.query)
    query.delete('raw')
    query['dl'] = '0'
    uri.query = query.to_query
    uri.to_s
  end

  def snap(url)
    uri = URI.parse(url)
    query = CGI.parse(uri.query)
    username = query['username'][0] || query['user'][0]
    project = query['projectname'][0] || query['project'][0]
    "https://snap.berkeley.edu/embed?projectname=#{project}&username=#{username}&showTitle=true&showAuthor=true&editButton=true&pauseButton=true"
  end
end
