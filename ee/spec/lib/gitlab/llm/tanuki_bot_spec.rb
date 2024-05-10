# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::TanukiBot, feature_category: :duo_chat do
  # rubocop:disable RSpec/MultipleMemoizedHelpers -- after ai_gateway_docs_search flag removal many let can be removed
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:embeddings) { create_list(:vertex_gitlab_documentation, 2) }

    let(:empty_response_message) { "I'm sorry, I was not able to find any documentation to answer your question." }
    let(:unsupported_response_message) do
      "It seems your question relates to GitLab documentation. " \
        "Unfortunately, this feature is not yet available in this GitLab instance. " \
        "Your feedback is welcome."
    end

    let(:question) { 'A question' }
    let(:answer) { 'The answer.' }
    let(:logger) { instance_double('Gitlab::Llm::Logger') }
    let(:instance) { described_class.new(current_user: user, question: question, logger: logger) }
    let(:vertex_model) { ::Embedding::Vertex::GitlabDocumentation }
    let(:vertex_args) { { content: question } }
    let(:vertex_client) { ::Gitlab::Llm::VertexAi::Client.new(user) }
    let(:ai_gateway_client) { ::Gitlab::Llm::AiGateway::Client.new(user) }
    let(:anthropic_client) { ::Gitlab::Llm::Anthropic::Client.new(user) }
    let(:embedding) { Array.new(1536, 0.5) }
    let(:vertex_embedding) { Array.new(768, 0.5) }
    let(:predictions) { [{ "embeddings" => { "values" => vertex_embedding } }] }
    let(:error) { nil }
    let(:vertex_response) { { "predictions" => predictions, "error" => error } }
    let(:attrs) { embeddings.map(&:id).map { |x| "CNT-IDX-#{x}" }.join(", ") }
    let(:completion_response) { "#{answer} ATTRS: #{attrs}" }

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

    let(:status_code) { 200 }
    let(:success) { true }

    subject(:execute) { instance.execute }

    before do
      allow(vertex_response).to receive(:success?).and_return(success)
      allow(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)
    end

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
        stub_feature_flags(ai_gateway_docs_search: false)
      end

      context 'when on Gitlab.com' do
        before do
          allow(::Gitlab).to receive(:org_or_com?).and_return(true)
        end

        context 'when no user is provided' do
          let(:user) { nil }

          it 'returns an empty response message' do
            expect(execute.response_body).to eq(empty_response_message)
          end
        end

        context 'when user has AI features disabled' do
          before do
            allow(described_class).to receive(:enabled_for?).with(user: user).and_return(false)
          end

          it 'returns an empty response message' do
            expect(execute.response_body).to eq(empty_response_message)
          end
        end

        context 'when user has AI features enabled' do
          before do
            allow(::Gitlab::Llm::VertexAi::Client).to receive(:new).and_return(vertex_client)
            allow(::Gitlab::Llm::Anthropic::Client).to receive(:new).and_return(anthropic_client)
            allow(described_class).to receive(:enabled_for?).and_return(true)
          end

          context 'when embeddings table is empty (no embeddings are stored in the table)' do
            it 'returns an empty response message' do
              vertex_model.connection.execute("truncate #{vertex_model.table_name}")

              expect(execute.response_body).to eq(empty_response_message)
            end
          end

          it 'executes calls through to anthropic' do
            embeddings

            expect(anthropic_client).to receive(:stream).once.and_return(completion_response)
            expect(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)

            execute
          end

          it 'calls the duo_chat_documentation pipeline for the emedded content' do
            allow(Banzai).to receive(:render).and_return('absolute_links_content')

            expect(anthropic_client).to receive(:stream)
              .with(
                prompt: a_string_including('absolute_links_content')
              ).once.and_return(completion_response)

            execute
          end

          it 'yields the streamed response to the given block' do
            embeddings

            allow(anthropic_client).to receive(:stream).once
                                          .and_yield({ "completion" => answer })
                                          .and_return(completion_response)

            expect(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)

            expect { |b| instance.execute(&b) }.to yield_with_args(answer)
          end

          it 'raises an error when request failed' do
            embeddings

            expect(logger).to receive(:info).with(message: "Streaming error", error: { "message" => "some error" })
            expect(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)
            allow(anthropic_client).to receive(:stream).once.and_yield({ "error" => { "message" => "some error" } })

            execute
          end

          context 'when embedding database does not exist' do
            before do
              allow(Embedding::Vertex::GitlabDocumentation).to receive(:table_exists?).and_return(false)
            end

            it 'returns an unsupported_response response message' do
              expect(execute.response_body).to eq(unsupported_response_message)
            end
          end

          context 'when searching for embeddings' do
            let(:error) { { "message" => "some error" } }

            context 'when the embeddings request is unsuccesful' do
              let(:success) { false }

              it 'logs an error message' do
                expect(logger).to receive(:info_or_debug).with(user, message: "Could not generate embeddings",
                  error: "some error")
                expect(execute.response_body).to eq(empty_response_message)
                execute
              end
            end

            context 'when the embeddings request has no predictions' do
              let(:predictions) { [] }

              it 'returns empty response' do
                expect(execute.response_body).to eq(empty_response_message)
                execute
              end
            end
          end
        end

        context 'when ai_duo_chat_switch FF is disabled' do
          before do
            stub_feature_flags(ai_duo_chat_switch: false)
          end

          it 'returns an empty response message' do
            expect(execute.response_body).to eq(empty_response_message)
          end
        end
      end

      context 'when ai_duo_chat_switch FF is disabled' do
        before do
          stub_feature_flags(ai_duo_chat_switch: false)
        end

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end

      context 'when the feature flags are enabled' do
        before do
          allow(::Gitlab::Llm::VertexAi::Client).to receive(:new).and_return(vertex_client)
          allow(::Gitlab::Llm::Anthropic::Client).to receive(:new).and_return(anthropic_client)
          allow(user).to receive(:any_group_with_ai_available?).and_return(true)
        end

        context 'when the question is not provided' do
          let(:question) { nil }

          it 'returns an empty response message' do
            expect(execute.response_body).to eq(empty_response_message)
          end
        end

        context 'when no neighbors are found' do
          before do
            allow(vertex_model).to receive(:neighbor_for).and_return(vertex_model.none)
          end

          it 'returns an i do not know' do
            expect(execute.response_body).to eq(empty_response_message)
          end
        end
      end
    end

    describe 'execute with ai_gateway_docs_search enabled' do
      before do
        stub_feature_flags(ai_gateway_docs_search: true)
        allow(License).to receive(:feature_available?).and_return(true)
        allow(logger).to receive(:info_or_debug)

        allow(described_class).to receive(:enabled_for?).and_return(true)

        allow(::Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_gateway_client)
        allow(::Gitlab::Llm::AiGateway::DocsClient).to receive(:new).and_return(docs_search_client)

        allow(ai_gateway_client).to receive(:stream).and_return(completion_response)
        allow(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)
      end

      it 'executes calls and returns ResponseModifier' do
        expect(ai_gateway_client).to receive(:stream)
          .with(prompt: a_string_including('content'), model: 'claude-2.1')
          .once.and_return(completion_response)
        expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

        expect(execute).to be_an_instance_of(::Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot)
      end

      it 'yields the streamed response to the given block' do
        allow(Banzai).to receive(:render).and_return('absolute_links_content')

        expect(ai_gateway_client)
          .to receive(:stream)
          .with(prompt: a_string_including('content'), model: 'claude-2.1')
          .once
          .and_yield(answer)
          .and_return(completion_response)

        expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

        expect { |b| instance.execute(&b) }.to yield_with_args(answer)
      end

      it 'raises an error when request failed' do
        expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)
        allow(ai_gateway_client).to receive(:stream).once.and_yield({ "error" => { "message" => "some error" } })

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
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
