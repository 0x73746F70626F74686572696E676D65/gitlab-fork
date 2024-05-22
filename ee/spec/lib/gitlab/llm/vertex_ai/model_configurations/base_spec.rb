# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ModelConfigurations::Base, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  subject(:config) { described_class.new(user: user) }

  describe '#url' do
    before do
      stub_const("#{described_class}::NAME", 'awesome-model')
    end

    it 'returns url' do
      puts "#{self.class} #{__method__} Gitlab::AiGateway.url: #{Gitlab::AiGateway.url}"
      expect(subject.url).to eq(
        "#{Gitlab::AiGateway.url}/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION" \
          "/publishers/google/models/awesome-model:predict"
      )
    end

    context 'when use_ai_gateway_proxy is disabled' do
      before do
        stub_feature_flags(use_ai_gateway_proxy: false)
      end

      it 'raises MissingConfigurationError' do
        expect { subject.url }.to raise_error(
          Gitlab::Llm::VertexAi::ModelConfigurations::Base::MissingConfigurationError
        )
      end
    end
  end
end
