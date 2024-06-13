# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::SummarizeComments::Executor, feature_category: :duo_chat do
  let(:input_variables) { { input: "user input", suggestions: "" } }
  let(:tool) { described_class.new(context: context, options: input_variables) }

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('SummarizeComments')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      desc = 'This tool is useful when you need to create a summary ' \
             'of all notes, comments or discussions on a given, identified resource.'

      expect(described_class::DESCRIPTION).to include(desc)
    end
  end

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:issue1) { create(:issue, project: project) }

    before do
      stub_application_setting(check_namespace_plan: true)
      stub_licensed_features(summarize_comments: true, ai_features: true, experimental_features: true, ai_chat: true)

      group.add_developer(user)
      group.update!(experiment_features_enabled: true)
    end

    context 'when issue is identified' do
      let(:context) do
        Gitlab::Llm::Chain::GitlabContext.new(
          container: project,
          resource: issue1,
          current_user: user,
          ai_request: ::Gitlab::Llm::Chain::Requests::Anthropic.new(user, unit_primitive: 'duo_chat')
        )
      end

      context 'when user has permission to read resource' do
        context 'when resource has no comments to summarize' do
          it 'responds without making an AI call' do
            expect(tool).not_to receive(:request)

            response = "Issue ##{issue1.iid} has no comments to be summarized."
            expect(tool.execute.content).to eq(response)
          end
        end

        context 'when resource has comments to summarize' do
          let_it_be(:notes) { create_pair(:note_on_issue, project: project, noteable: issue1) }

          context 'when no permissions to use ai features' do
            before do
              stub_licensed_features(summarize_comments: false, ai_features: false)
            end

            it 'responds with error' do
              expect(tool).not_to receive(:request)

              answer = tool.execute

              response = "I'm sorry, I can't generate a response. " \
                "The items you're asking about either don't exist, or you don't have access to them."
              expect(answer.content).to eq(response)
              expect(answer.error_code).to eq("M3003")
            end
          end

          context 'when resource was already summarized' do
            before do
              context.tools_used << described_class
            end

            it 'returns already summarized response' do
              expect(tool).not_to receive(:request)

              response = "You already have the summary of the notes, comments, discussions for the " \
                         "Issue ##{issue1.iid} in your context, read carefully."

              expect(tool.execute.content).to include(response)
            end
          end

          it 'responds with summary' do
            expect(tool).to receive(:request).and_return("some response")

            response = "Here is the summary for Issue #1 comments:"
            expect(tool.execute.content).to include(response)
          end

          context 'with raw_ai_response: true' do
            let(:input_variables) { { input: "user input", suggestions: "", raw_ai_response: true } }

            it 'calls given block with chunks' do
              expect(tool).to receive(:request).and_yield("some").and_yield(" response")

              expect { |b| tool.execute(&b) }.to yield_successive_args("some", " response")
            end

            it 'returns content when no block is given' do
              expect(tool).to receive(:request).and_return('some response')

              expect(tool.execute.content).to eq('some response')
            end
          end
        end
      end
    end
  end
end
