# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::CompletionsFactory, feature_category: :ai_abstraction_layer do
  describe ".completion!" do
    let(:prompt_message) { build(:ai_message, ai_action: completion_name) }

    context 'with existing completion' do
      let(:completion_name) { :summarize_review }
      let(:expected_params) { { action: completion_name }.merge(params) }
      let(:params) { {} }

      it 'returns completion service' do
        completion_class = ::Gitlab::Llm::VertexAi::Completions::SummarizeReview
        template_class = ::Gitlab::Llm::Templates::SummarizeReview

        expect(completion_class).to receive(:new).with(prompt_message, template_class,
          expected_params).and_call_original

        completion = described_class.completion!(prompt_message, params)

        expect(completion).to be_a(completion_class)
      end

      context 'with params' do
        let(:params) { { include_source_code: true } }
        let(:completion_name) { :explain_vulnerability }

        it 'passes parameters to the completion class' do
          completion_class = ::Gitlab::Llm::Completions::ExplainVulnerability
          template_class = ::Gitlab::Llm::Templates::ExplainVulnerability

          expect(completion_class).to receive(:new).with(prompt_message, template_class,
            expected_params).and_call_original

          completion = described_class.completion!(prompt_message, params)

          expect(completion).to be_a(completion_class)
        end
      end
    end

    context 'with invalid completion' do
      let(:completion_name) { :invalid_name }

      it 'raises name error completion service' do
        expect do
          described_class.completion!(prompt_message)
        end.to raise_error(NameError, "completion class for action invalid_name not found")
      end
    end
  end
end
