# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Response, feature_category: :global_search do
  let_it_be(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
  let_it_be(:raw_response_success) { File.read Rails.root.join(fixtures_path, 'flightjs_response_success.json') }
  let_it_be(:raw_response_failure) { File.read Rails.root.join(fixtures_path, 'response_failure.json') }

  let(:parsed_response) { ::Gitlab::Json.parse(raw_response) }
  let(:raw_response) { raw_response_success }

  subject(:zoekt_response) { described_class.new(parsed_response) }

  describe '#success?' do
    it 'returns true' do
      expect(zoekt_response.success?).to eq(true)
    end

    context 'when failed response' do
      let(:raw_response) { raw_response_failure }

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
      let(:raw_response) { raw_response_failure }

      it 'returns error message' do
        expect(zoekt_response.error_message).to match(/error parsing regexp/)
      end
    end
  end

  describe '#file_count' do
    it 'returns the number of files' do
      expect(zoekt_response.file_count).to eq(3)
    end
  end

  describe '#match_count' do
    it 'returns the number of matches' do
      expect(zoekt_response.match_count).to eq(20)
    end
  end
end
