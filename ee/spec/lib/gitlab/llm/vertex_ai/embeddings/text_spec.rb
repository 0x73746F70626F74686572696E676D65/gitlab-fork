# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Embeddings::Text, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let(:text) { 'example text' }
  let(:type) { 'issue' }
  let(:embeddings) { [1, 2, 3] }
  let(:success) { true }
  let(:context) { { action: 'embedding' } }
  let(:primitive) { 'documentation_search' }

  subject(:execute) do
    described_class.new(text, user: user, tracking_context: context, unit_primitive: primitive).execute
  end

  describe '#execute' do
    let(:example_response) do
      {
        "predictions" => [
          {
            "embeddings" => {
              "values" => embeddings,
              "statistics" => {
                "token_count" => 3
              },
              "metadata" => {
                "billableCharacterCount" => 4
              }
            }
          }
        ]
      }.to_json
    end

    before do
      allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
        allow(client).to receive(:text_embeddings).and_return(example_response)
      end
      allow(example_response).to receive(:success?).and_return(success)
    end

    context 'when the text model returns a successful response' do
      it 'returns the embeddings from the response' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect(execute).to eq(embeddings)
      end
    end

    context 'when the API returns an error response' do
      let(:error_hash) { { error: { message: 'error' } }.to_json }

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:text_embeddings).and_return(error_hash)
        end
      end

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(error_hash)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /error/)
      end
    end

    context 'when the API returns an unsuccessful response' do
      let(:success) { false }

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /Could not generate embedding/)
      end
    end

    context 'when the API returns an empty response' do
      let(:example_response) { { 'predictions' => [] } }

      it 'raises an error' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Embeddings)
          .to receive(:new)
          .with(example_response)
          .and_call_original

        expect { execute }.to raise_error(StandardError, /Could not generate embedding/)
      end
    end

    context 'when an error is raised' do
      let(:error) { StandardError.new('Error') }

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:text_embeddings).and_raise(error)
        end
      end

      it 'raises an error' do
        expect { execute }.to raise_error(StandardError)
      end
    end
  end
end
