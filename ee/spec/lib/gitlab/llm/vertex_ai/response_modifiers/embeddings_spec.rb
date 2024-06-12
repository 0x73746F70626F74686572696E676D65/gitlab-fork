# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings, feature_category: :ai_abstraction_layer do
  let(:values) { [1, 2, 3] }

  describe '#response_body' do
    subject(:response_body) { described_class.new(ai_response.to_json).response_body }

    context 'when AI response predictions has embeddings' do
      let(:ai_response) { { predictions: [{ embeddings: { values: values } }] } }

      it 'returns embeddings' do
        expect(response_body).to eq(values)
      end
    end

    context 'when there are errors' do
      let(:ai_response) { { error: { message: 'error' } } }

      it 'returns blank string' do
        expect(response_body).to be_blank
      end
    end

    context 'when AI response is nil' do
      let(:ai_response) { nil }

      it 'returns blank string' do
        expect(response_body).to be_blank
      end
    end
  end

  describe '#errors' do
    subject(:errors) { described_class.new(ai_response.to_json).errors }

    context 'when the response contains errors' do
      let(:ai_response) { { error: 'error' } }

      it 'returns array of errors' do
        expect(errors).to eq(['error'])
      end
    end

    context 'when the response contains errors in a message object' do
      let(:ai_response) { { error: { message: 'error' } } }

      it 'returns array of errors' do
        expect(errors).to eq(['error'])
      end
    end

    context 'when there are no errors' do
      let(:ai_response) { { predictions: [{ embeddings: { values: values } }] } }

      it 'returns empty array' do
        expect(errors).to be_empty
      end
    end

    context 'when AI response is nil' do
      let(:ai_response) { nil }

      it 'returns empty array' do
        expect(errors).to be_empty
      end
    end
  end
end
