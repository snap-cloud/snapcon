# frozen_string_literal: true

require 'spec_helper'

describe EmbeddableURL do
  describe '#iframe_url' do
    it 'returns the original url if no transformations apply' do
      url = 'https://example.com'
      expect(EmbeddableURL.new(url, 'title').iframe_url).to eq url
    end

    it 'transforms a Google Drive URL' do
      url = EmbeddableURL.new('https://docs.google.com/presentation/d/1eGbEQtcOPW2N2P5rKfBVfSo2zn4C307Sh6C7vpJsruE/edit#slide=id.g1088c029399_0_47', 'title').iframe_url
      expect(url).to include '/embed'
      expect(url).not_to include('/edit')
    end

    it 'transforms a Dropbox URL' do
      url = EmbeddableURL.new('https://www.dropbox.com/scl/fi/49gkp6ghfnxgqex64zvzd/Guzdial-SnapCon23.pdf?rlkey=ecwvmcmfscqtwfq21l3kzqcul&dl=1', 'title').iframe_url
      expect(url).to include('dl=0')
      expect(url).not_to include('raw=')
    end

    it 'transforms a Snap! Project URL' do
      url = EmbeddableURL.new('https://snap.berkeley.edu/project?username=jedi_force&projectname=Autograder%2dlite', 'title').iframe_url
      expect(url).to include('/embed')
    end
  end

  # it 'parses snap url' do
  #   url = 'https://snap.berkeley.edu/project?username=avi_shor&projectname=stamps'
  #   transformed_url = Commercial.generate_snap_embed(url)
  #   expected_url = 'https://snap.berkeley.edu/embed?projectname=stamps&username=avi_shor&showTitle=true&showAuthor=true&editButton=true&pauseButton=true'
  #   expect(transformed_url).to eq expected_url
  # end
  # TODO: Test ifram generation, snap-embedding
end
