# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ResponseModifiers::Base, feature_category: :ai_abstraction_layer do
  let(:response) { "I'm GitLab Duo!" }
  let(:response_body) { %("#{response}") }
  let(:ai_response) { instance_double(HTTParty::Response, body: response_body) }
  let(:base_modifier) { described_class.new(ai_response) }

  describe '#response_body' do
    it 'returns the parsed response body' do
      expect(base_modifier.response_body).to eq(response)
    end
  end

  describe '#errors' do
    context 'when response was successful' do
      it 'returns an empty array' do
        expect(base_modifier.errors).to eq([])
      end
    end

    context 'when response contains errors' do
      let(:error) { 'Error message' }

      context 'when the detail is an string' do
        let(:response_body) { %({"detail": "#{error}"}) }

        it 'returns an array with the error message' do
          expect(base_modifier.errors).to eq([error])
        end
      end

      context 'when the detail is an array' do
        let(:response_body) { %({"detail": [{"msg": "#{error}"}]}) }

        it 'returns an array with the error message' do
          expect(base_modifier.errors).to eq([error])
        end
      end
    end
  end
end
