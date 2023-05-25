# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Llm::GraphqlSubscriptionResponseService, feature_category: :no_category do # rubocop: disable RSpec/InvalidFeatureCategory
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let(:response_body) { 'Some response' }
  let(:options) { { request_id: 'uuid' } }

  let(:ai_response_json) do
    '{
      "id": "cmpl-72baOZiNHv2njeNoWqPZ12xozfPv7",
      "object": "text_completion",
      "created": 1680855492,
      "model": "text-davinci-003",
      "choices": [
        {
          "text": "Some response",
          "index": 0,
          "logprobs": null,
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 8,
        "completion_tokens": 17,
        "total_tokens": 25
      }
    }'
  end

  let(:response_modifier) { Gitlab::Llm::OpenAi::ResponseModifiers::Completions.new(ai_response_json) }

  shared_examples 'graphql subscription response' do
    let(:uuid) { 'u-u-i-d' }
    let(:payload) do
      {
        id: uuid,
        model_name: resource.class.name,
        response_body: response_body,
        request_id: 'uuid',
        role: 'assistant',
        errors: []
      }
    end

    before do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
    end

    it 'triggers subscription' do
      expect(GraphqlTriggers)
        .to receive(:ai_completion_response)
        .with(user.to_global_id, resource.to_global_id, payload)

      subject
    end

    it 'caches response' do
      expect_next_instance_of(::Gitlab::Llm::Cache) do |cache|
        expect(cache).to receive(:add)
          .with(payload.slice(:request_id, :errors, :role).merge(content: payload[:response_body]))
      end

      subject
    end
  end

  shared_examples 'with a markup format option' do
    let(:options) { { markup_format: :html, request_id: 'uuid' } }

    it_behaves_like 'graphql subscription response' do
      let(:response_body) { '<p data-sourcepos="1:1-1:13" dir="auto">Some response</p>' }
    end
  end

  describe '#execute' do
    subject { described_class.new(user, resource, response_modifier, options: options).execute }

    let_it_be(:resource) { create(:merge_request, source_project: project) }

    context 'without user' do
      let(:user) { nil }

      it 'does not broadcast subscription' do
        expect(GraphqlTriggers).not_to receive(:ai_completion_response)

        subject
      end
    end

    context 'for a merge request' do
      it_behaves_like 'graphql subscription response'
      it_behaves_like 'with a markup format option'
    end

    context 'for a work item' do
      let_it_be(:resource) { create(:work_item, project: project) }

      it_behaves_like 'graphql subscription response'
      it_behaves_like 'with a markup format option'
    end

    context 'for an issue' do
      let_it_be(:resource) { create(:issue, project: project) }

      it_behaves_like 'graphql subscription response'
      it_behaves_like 'with a markup format option'
    end

    context 'for an epic' do
      let_it_be(:resource) { create(:epic, group: group) }

      it_behaves_like 'graphql subscription response'
      it_behaves_like 'with a markup format option'
    end
  end
end
