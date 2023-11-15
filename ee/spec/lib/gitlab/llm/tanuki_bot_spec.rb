# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::TanukiBot, feature_category: :duo_chat do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:embeddings) { create_list(:vertex_gitlab_documentation, 2) }

    let(:empty_response_message) { "I'm sorry, I was not able to find any documentation to answer your question." }
    let(:question) { 'A question' }
    let(:answer) { 'The answer.' }
    let(:logger) { instance_double('Logger') }
    let(:instance) { described_class.new(current_user: user, question: question, logger: logger) }
    let(:vertex_model) { ::Embedding::Vertex::GitlabDocumentation }
    let(:vertex_args) { { content: question } }
    let(:vertex_client) { ::Gitlab::Llm::VertexAi::Client.new(user) }
    let(:anthropic_client) { ::Gitlab::Llm::Anthropic::Client.new(user) }
    let(:embedding) { Array.new(1536, 0.5) }
    let(:vertex_embedding) { Array.new(768, 0.5) }
    let(:openai_response) { { "data" => [{ "embedding" => embedding }] } }
    let(:vertex_response) { { "predictions" => [{ "embeddings" => { "values" => vertex_embedding } }] } }
    let(:attrs) { embeddings.map(&:id).map { |x| "CNT-IDX-#{x}" }.join(", ") }
    let(:completion_response) { "#{answer} ATTRS: #{attrs}" }

    let(:status_code) { 200 }
    let(:success) { true }

    subject(:execute) { instance.execute }

    describe 'enabled_for?' do
      describe 'when :ai_global_switch is true' do
        where(:feature_available, :ai_feature_enabled, :result) do
          [
            [false, false, false],
            [false, true, false],
            [true, false, false],
            [true, true, true]
          ]
        end

        with_them do
          before do
            allow(License).to receive(:feature_available?).and_return(feature_available)
            allow(described_class).to receive(:ai_feature_enabled?).and_return(ai_feature_enabled)
          end

          it 'returns correct result' do
            expect(described_class.enabled_for?(user: user)).to be(result)
          end
        end
      end

      describe 'when ai_global_switch is false' do
        before do
          allow(License).to receive(:feature_available?).and_return(true)
          allow(described_class).to receive(:ai_feature_enabled?).and_return(true)

          stub_feature_flags(ai_global_switch: false)
        end

        it 'returns false' do
          expect(described_class.enabled_for?(user: user)).to be(false)
        end
      end
    end

    describe '#ai_feature_enabled?' do
      subject { described_class.ai_feature_enabled?(user) }

      context 'when not on gitlab.com' do
        it { is_expected.to be_truthy }
      end

      context 'when on gitlab.com', :saas do
        it { is_expected.to be_falsey }

        context 'when user has a group with ai feature enabled' do
          before do
            allow(user).to receive(:any_group_with_ai_available?).and_return(true)
          end

          it { is_expected.to be_truthy }
        end

        context 'when user has no group with ai feature enabled' do
          before do
            allow(user).to receive(:any_group_with_ai_available?).and_return(false)
          end

          it { is_expected.to be_falsey }
        end
      end
    end

    describe '#show_breadcrumbs_entry_point', :saas, :use_clean_rails_redis_caching do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with ai features enabled for group'

        context 'when user is a member of the group' do
          before_all do
            group.add_guest(user)
          end

          context 'when container is a group' do
            it 'returns true' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(true)
            end
          end

          context 'when container is a project' do
            let_it_be(:project) { create(:project, group: group) }

            it 'returns true' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: project
                )
              ).to be(true)
            end
          end

          context 'when missing Ultimate SaaS license' do
            let_it_be(:group) { create(:group) }

            it 'returns false' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(false)
            end
          end

          context 'when tanuki_bot_breadcrumbs_entry_point feature flag is disabled' do
            it 'returns false' do
              stub_feature_flags(tanuki_bot_breadcrumbs_entry_point: false)

              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(false)
            end
          end
        end

        context 'when user is not a member of the group' do
          context 'when the user has AI enabled via another group' do
            it 'returns false' do
              allow(user).to receive(:any_group_with_ai_available?).and_return(true)

              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(false)
            end
          end

          context 'when user does not have AI enabled via any group' do
            it 'returns false' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(false)
            end
          end
        end

        context 'when user not present' do
          it 'returns false' do
            expect(
              described_class.show_breadcrumbs_entry_point?(
                user: false,
                container: group
              )
            ).to be(false)
          end
        end
      end

      context 'when container is not a group with AI enabled' do
        context 'when user has AI enabled' do
          before do
            allow(user).to receive(:any_group_with_ai_available?).and_return(true)
          end

          context 'when container is a group' do
            include_context 'with experiment features disabled for group'

            it 'returns false' do
              allow(user).to receive(:any_group_with_ai_available?).and_return(true)

              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: group
                )
              ).to be(false)
            end
          end

          context 'when container is a project in a personal namespace' do
            let_it_be(:project) { create(:project, namespace: user.namespace) }

            it 'returns false' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: project
                )
              ).to be(false)
            end
          end

          context 'when container is not present' do
            # for example, Dashboard or User Settings pages
            it 'returns true' do
              expect(
                described_class.show_breadcrumbs_entry_point?(
                  user: user,
                  container: nil
                )
              ).to be(true)
            end
          end
        end
      end
    end

    describe 'execute' do
      before do
        allow(License).to receive(:feature_available?).and_return(true)
        allow(logger).to receive(:debug)
      end

      context 'with the ai_tanuki_bot license not available' do
        before do
          allow(License).to receive(:feature_available?).with(:ai_tanuki_bot).and_return(false)
        end

        it 'returns an empty response message' do
          expect(execute.response_body).to eq(empty_response_message)
        end
      end

      context 'with the tanuki_bot license available' do
        context 'when on Gitlab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(true)
          end

          context 'when no user is provided' do
            let(:user) { nil }

            it 'returns an empty response message' do
              expect(execute.response_body).to eq(empty_response_message)
            end
          end

          context 'when #ai_feature_enabled is false' do
            before do
              allow(described_class).to receive(:ai_feature_enabled?).and_return(false)
            end

            it 'returns an empty response message' do
              expect(execute.response_body).to eq(empty_response_message)
            end
          end

          context 'when #ai_feature_enabled is true' do
            before do
              allow(::Gitlab::Llm::VertexAi::Client).to receive(:new).and_return(vertex_client)
              allow(::Gitlab::Llm::Anthropic::Client).to receive(:new).and_return(anthropic_client)
              allow(described_class).to receive(:ai_feature_enabled?).and_return(true)
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
              allow(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)
              allow(Banzai).to receive(:render).and_return('absolute_links_content')

              expect(anthropic_client).to receive(:stream)
                .with(
                  prompt: a_string_including('absolute_links_content'),
                  options: { model: "claude-instant-1.1" }
                ).once.and_return(completion_response)

              execute
            end

            context 'when duo_chat_absolute_doc_links is disabled' do
              before do
                stub_feature_flags(duo_chat_absolute_doc_links: false)
              end

              it 'does not call duo_chat_documentation pipeline' do
                allow(anthropic_client).to receive(:stream).once.and_return(completion_response)
                allow(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)

                expect(Banzai).not_to receive(:render)

                execute
              end
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
          end
        end

        context 'when ai_global_switch FF is disabled' do
          before do
            stub_feature_flags(ai_global_switch: false)
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
              allow(vertex_client).to receive(:text_embeddings).with(**vertex_args).and_return(vertex_response)
            end

            it 'returns an i do not know' do
              expect(execute.response_body).to eq(empty_response_message)
            end
          end
        end
      end
    end
  end
end
