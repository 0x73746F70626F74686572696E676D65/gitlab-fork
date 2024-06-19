# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::TanukiBot, feature_category: :duo_chat do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:embeddings) { create_list(:vertex_gitlab_documentation, 2) }

    let(:empty_response_message) do
      "I'm sorry, I couldn't find any documentation to answer your question. Error code: M2000"
    end

    let(:question) { 'A question' }
    let(:answer) { 'The answer.' }
    let(:logger) { instance_double('Gitlab::Llm::Logger') }
    let(:instance) { described_class.new(current_user: user, question: question, logger: logger) }
    let(:ai_gateway_request) { ::Gitlab::Llm::Chain::Requests::AiGateway.new(user) }
    let(:attrs) { embeddings.map(&:id).map { |x| "CNT-IDX-#{x}" }.join(", ") }
    let(:completion_response) { { 'response' => "#{answer} ATTRS: #{attrs}" } }

    let(:docs_search_client) { ::Gitlab::Llm::AiGateway::DocsClient.new(user) }
    let(:docs_search_args) { { query: question } }
    let(:docs_search_response) do
      {
        'response' => {
          'results' => [
            {
              'id' => 1,
              'content' => 'content',
              'metadata' => 'metadata'
            }
          ]
        }
      }
    end

    subject(:execute) { instance.execute }

    describe '.enabled_for?', :use_clean_rails_redis_caching do
      let_it_be_with_reload(:group) { create(:group) }
      let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

      context 'when user present and container is not present' do
        where(:ai_duo_chat_switch_enabled, :allowed, :result) do
          [
            [true, true, true],
            [true, false, false],
            [false, true, false],
            [false, false, false]
          ]
        end

        with_them do
          before do
            stub_feature_flags(ai_duo_chat_switch: ai_duo_chat_switch_enabled)
            allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
              .and_return(authorizer_response)
          end

          it 'returns correct result' do
            expect(described_class.enabled_for?(user: user)).to be(result)
          end
        end
      end

      context 'when user and container are both present' do
        where(:ai_duo_chat_switch_enabled, :allowed, :result) do
          [
            [true, true, true],
            [true, false, false],
            [false, true, false],
            [false, false, false]
          ]
        end

        with_them do
          before do
            stub_feature_flags(ai_duo_chat_switch: ai_duo_chat_switch_enabled)
            allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).with(user: user, container: group)
              .and_return(authorizer_response)
          end

          it 'returns correct result' do
            expect(described_class.enabled_for?(user: user, container: group)).to be(result)
          end
        end
      end

      context 'when user is not present' do
        it 'returns false' do
          expect(described_class.enabled_for?(user: nil)).to be(false)
        end
      end
    end

    describe '.show_breadcrumbs_entry_point' do
      where(:ai_features_enabled_for_user, :result) do
        [
          [true, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(described_class).to receive(:enabled_for?).with(user: user, container: nil)
            .and_return(ai_features_enabled_for_user)
        end

        it 'returns correct result' do
          expect(described_class.show_breadcrumbs_entry_point?(user: user)).to be(result)
        end
      end
    end

    describe 'execute' do
      before do
        allow(License).to receive(:feature_available?).and_return(true)
        allow(logger).to receive(:info_or_debug)

        allow(described_class).to receive(:enabled_for?).and_return(true)

        allow(::Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).and_return(ai_gateway_request)
        allow(::Gitlab::Llm::AiGateway::DocsClient).to receive(:new).and_return(docs_search_client)

        allow(ai_gateway_request).to receive(:request).and_return(completion_response)
        allow(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)
      end

      it 'executes calls and returns ResponseModifier' do
        expect(ai_gateway_request).to receive(:request)
          .with(prompt: instance_of(Array),
            options: { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_SONNET, max_tokens: 256 })
          .once.and_return(completion_response)
        expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

        expect(execute).to be_an_instance_of(::Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot)
      end

      it 'yields the streamed response to the given block' do
        allow(Banzai).to receive(:render).and_return('absolute_links_content')

        expect(ai_gateway_request)
          .to receive(:request)
          .with(prompt: instance_of(Array), options:
            { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_SONNET, max_tokens: 256 })
          .once
          .and_yield(answer)
          .and_return(completion_response)

        expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

        expect { |b| instance.execute(&b) }.to yield_with_args(answer)
      end

      it 'raises an error when request failed' do
        expect(logger).to receive(:info).with(message: "Streaming error", error: anything)
        allow(ai_gateway_request).to receive(:request).once
                                                      .and_raise(::Gitlab::Llm::AiGateway::Client::ConnectionError.new)

        execute
      end

      context 'when user has AI features disabled' do
        before do
          allow(described_class).to receive(:enabled_for?).with(user: user).and_return(false)
        end

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end

      context 'when the question is not provided' do
        let(:question) { nil }

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end

      context 'when no documents are found' do
        let(:docs_search_response) { {} }

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end

      context 'when DocsClient returns nil' do
        let(:docs_search_response) { nil }

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end
    end
  end
end
