# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VersionCheck, :use_clean_rails_memory_store_caching do
  include ReactiveCachingHelpers

  describe '.url' do
    it 'returns the correct URL' do
      expect(described_class.url).to match(%r{\A#{Regexp.escape(described_class.host)}/check\.json\?gitlab_info=\w+})
    end
  end

  context 'reactive cache properties' do
    describe '.reactive_cache_refresh_interval' do
      it 'returns 12.hours' do
        expect(described_class.reactive_cache_refresh_interval).to eq(12.hours)
      end
    end

    describe '.reactive_cache_lifetime' do
      it 'returns 7.days' do
        expect(described_class.reactive_cache_lifetime).to eq(7.days)
      end
    end
  end

  describe '#calculate_reactive_cache' do
    context 'response code is 200' do
      before do
        stub_request(:get, described_class.url).to_return(status: 200, body: '{ "status": "success" }', headers: {})
      end

      it 'returns the response object' do
        expect(described_class.new.calculate_reactive_cache).to eq({ "status" => "success" })
      end
    end

    context 'response code is not 200' do
      before do
        stub_request(:get, described_class.url).to_return(status: 500, body: nil, headers: {})
      end

      it 'returns an error hash' do
        expect(described_class.new.calculate_reactive_cache).to eq({ error: 'version check failed', status: 500 })
      end
    end
  end

  describe '#response' do
    context 'cache returns value' do
      it 'returns the response object' do
        version_check = described_class.new
        data = { status: 'success' }
        stub_reactive_cache(version_check, data)

        expect(version_check.response).to eq(data)
      end
    end

    context 'cache returns error' do
      it 'returns nil and invalidates the reactive cache' do
        version_check = described_class.new
        stub_reactive_cache(version_check, error: 'version check failed')

        expect(version_check).to receive(:refresh_reactive_cache!).and_call_original
        expect(version_check.response).to be_nil
        expect(read_reactive_cache(version_check)).to be_nil
      end
    end
  end
end
