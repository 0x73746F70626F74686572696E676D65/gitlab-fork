# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::AiGateway, feature_category: :cloud_connector do
  describe '.url' do
    context 'when AI_GATEWAY_URL environment variable is set' do
      let(:url) { 'http://localhost:5052' }

      it 'returns the AI_GATEWAY_URL' do
        stub_env('AI_GATEWAY_URL', url)

        expect(described_class.url).to eq(url)
      end
    end

    context 'when AI_GATEWAY_URL environment variable is not set' do
      let(:url) { 'http:://example.com' }

      it 'returns the cloud connector url' do
        stub_env('AI_GATEWAY_URL', nil)
        allow(::CloudConnector::Config).to receive(:base_url).and_return(url)

        expect(described_class.url).to eq("#{url}/ai")
      end
    end
  end
end
