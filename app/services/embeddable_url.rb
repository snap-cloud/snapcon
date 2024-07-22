# Transform a URL to a version that allows iframes

class EmbeddableURL
  attr_accessor :url, :title

  DEFAULT_FRAME_ATTRS = 'width=560 height=315 frameborder=0 allowfullscreen'.freeze

  TRANSFORMATIONS = {
    /snap\.berkeley\.edu/ => :snap,
    /docs\.google\.com/   => :google_docs,
    /dropbox\.com/        => :dropbox
  }.freeze

  def initialize(url, title)
    # Do some normalizing so that URIs parse correctly.
    if url
      self.url = url.strip
    end
    self.title = title
  end

  def render_embed
    return render_dropbox if url.include?('dropbox.com')

    # TODO-A11Y: Set an iframe title
    "<iframe #{DEFAULT_FRAME_ATTRS} src='#{iframe_url}' #{iframe_title}></iframe>"
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
        <a href="#{dropbox(url)}"
        class="dropbox-embed" data-height="315px" data-width="560px"></a>
      </div>
    HTML
  end

  private

  def optional_params
    return '' unless url.include?('snap.berkeley')

    'allow="geolocation;microphone;camera"'
  end

  def google_docs(url)
    # replace /edit, /share, /comment with /embed and remove the querystring
    url.gsub(%r{(/edit|/share|/comment).*}, '/embed')
  end

  def dropbox(url)
    # debugger
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query)&.to_h
    params.delete('raw')
    params['dl'] = '0'
    # params['rlkey'] = params['rlkey']
    uri.query = params.to_query
    uri.to_s
  end

  def snap(url)
    uri = URI.parse(url)
    return url if uri.query.blank?

    args = URI.decode_www_form(uri.query).to_h
    username = args['username'] || args['user']
    projectname = args['projectname'] || args['project']

    return url if username.blank? || projectname.blank?

    query = URI.encode_www_form({
                                  'projectname' => projectname,
                                  'username'    => username,
                                  'showTitle'   => 'true',
                                  'showAuthor'  => 'true',
                                  'editButton'  => 'true',
                                  'pauseButton' => 'true'
                                })
    URI::HTTPS.build(host: uri.host, path: '/embed', query: query).to_s
  end

  def iframe_title
    if title
      "title='#{title} Embedded Media'"
    else
      'title="Embedded Media for Presentation"'
    end
  end
end
