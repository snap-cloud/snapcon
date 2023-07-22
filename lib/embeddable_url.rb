# Transform a URL to a version that allows iframes

class EmbeddableURL
  attr_accessor :url

  TRANSFORMATIONS = {
    /snap\.berkeley\.edu/ => snap,
    /docs\.google\.com/   => google_docs,
    /dropbox\.com/        => dropbox
  }.freeze

  def iframe_url
    TRANSFORMATIONS.each do |regex, fn|
      return fn.call(url) if url.match?(regex)
    end
    url
  end

  private

  def google_docs(url)
    # replace /edit, /share ,/comment with /embed and remove the querystring
    url.gsub(%r{(/edit|/share|/comment).*}, '/embed')
  end

  def dropbox(url)
    uri = URI.parse(url)
    query = CGI.parse(uri.query)
    query.delete('dl')
    query['raw'] = '1'
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
