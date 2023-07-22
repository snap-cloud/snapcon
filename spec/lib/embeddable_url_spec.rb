# frozen_string_literal: true

require 'spec_helper'

describe EmbeddableURL do
  describe '#iframe_url' do
    it 'returns the original url if no transformations apply' do
      url = 'https://example.com'
      expect(EmbeddableURL.new(url).iframe_url).to eq url
    end

    it 'returns the transformed url if a transformation applies' do
      url = 'https://docs.google.com'
      expect(EmbeddableURL.new(url).iframe_url).to include '/embed'
    end
  end
end
