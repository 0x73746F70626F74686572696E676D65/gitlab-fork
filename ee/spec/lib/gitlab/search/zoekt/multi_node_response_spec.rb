# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::MultiNodeResponse, feature_category: :global_search do
  let_it_be(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
  let_it_be(:raw_response_success) { File.read Rails.root.join(fixtures_path, 'flightjs_response_success.json') }
  let_it_be(:raw_response_success2) { File.read Rails.root.join(fixtures_path, 'typeahead_response_success.json') }
  let_it_be(:raw_response_failure) { File.read Rails.root.join(fixtures_path, 'response_failure.json') }

  let_it_be(:response_success) { ::Gitlab::Search::Zoekt::Response.new ::Gitlab::Json.parse(raw_response_success) }
  let_it_be(:response_success2) { ::Gitlab::Search::Zoekt::Response.new ::Gitlab::Json.parse(raw_response_success2) }
  let_it_be(:response_failure) { ::Gitlab::Search::Zoekt::Response.new ::Gitlab::Json.parse(raw_response_failure) }

  let(:successful_responses) do
    {
      1 => response_success,
      2 => response_success2
    }
  end

  let(:mixed_responses) do
    {
      1 => response_success,
      2 => response_failure
    }
  end

  let(:responses) { successful_responses }

  subject(:zoekt_response) { described_class.new(responses) }

  describe '#success?' do
    it 'returns true' do
      expect(zoekt_response.success?).to eq(true)
    end

    context 'when failed response' do
      let(:responses) { mixed_responses }

      it 'returns false' do
        expect(zoekt_response.success?).to eq(false)
      end
    end
  end

  describe '#error_message' do
    it 'returns nil' do
      expect(zoekt_response.error_message).to be_nil
    end

    context 'when failed response' do
      let(:responses) { mixed_responses }

      it 'returns error message' do
        expect(zoekt_response.error_message).to match(/error parsing regexp/)
      end
    end
  end

  describe '#file_count' do
    it 'returns the number of files' do
      expect(zoekt_response.file_count).to eq(4)
    end
  end

  describe '#match_count' do
    it 'returns the number of line matches' do
      expect(zoekt_response.match_count).to eq(32)
    end
  end

  describe '#ngram_match_count' do
    it 'returns the total number of matches' do
      expect(zoekt_response.ngram_match_count).to eq(50)
    end
  end

  describe '#each_file' do
    it 'merges results from all nodes' do
      result = []
      zoekt_response.each_file do |file|
        result << file['Score']
      end

      expect(result.map(&:to_f)).to eq(result.map(&:to_f).sort.reverse)
      expect(result.length).to eq(4)
    end
  end
end
