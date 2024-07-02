# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ExecuteMethodService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:issue) { build_stubbed(:issue) }

  let(:method) { :summarize_comments }
  let(:resource) { nil }
  let(:params) { {} }
  let(:options) { { request_id: 'uuid' }.merge(params) }
  let(:success) { true }
  let(:request_id) { 'uuid' }
  let(:chat_message) { instance_double(Gitlab::Llm::ChatMessage, request_id: request_id) }
  let(:service_response) do
    instance_double(
      ServiceResponse,
      success?: success,
      error?: !success,
      payload: { ai_message: chat_message }
    )
  end

  subject { described_class.new(user, resource, method, options).execute }

  before do
    allow(service_response).to receive(:[]).with(:ai_message).and_return(chat_message)
  end

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    context 'with a valid method' do
      where(:method, :resource, :service_class, :params) do
        :summarize_comments | issue | Llm::GenerateSummaryService | {}
        :explain_code | build_stubbed(:project) | Llm::ExplainCodeService | {}
        :explain_vulnerability | build_stubbed(:vulnerability,
          :with_findings) | Llm::ExplainVulnerabilityService | { include_source_code: true }
        :resolve_vulnerability | build_stubbed(:vulnerability,
          :with_findings) | Llm::ResolveVulnerabilityService | {}
        :categorize_question | user | Llm::Internal::CategorizeChatQuestionService | {}
        :generate_cube_query | user | Llm::ProductAnalytics::GenerateCubeQueryService | {}
      end

      with_them do
        it 'calls the correct service' do
          expect_next_instance_of(service_class, user, resource, options.merge(params)) do |instance|
            expect(instance).to receive(:execute).and_return(service_response)
          end

          expect(subject).to be_success
        end
      end
    end

    context 'when service returns an error' do
      let(:success) { false }
      let(:error_message) { 'failed' }

      before do
        allow(service_response).to receive(:message).and_return(error_message)
      end

      it 'returns an error' do
        expect_next_instance_of(Llm::GenerateSummaryService, user, resource, options) do |instance|
          expect(instance).to receive(:execute).and_return(service_response)
        end

        expect(subject).to be_error.and have_attributes(message: eq(error_message))
      end
    end

    context 'with an invalid method' do
      let(:method) { :invalid_method }

      it { is_expected.to be_error.and have_attributes(message: eq('Unknown method')) }
    end

    context 'with snowplow events' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:user) { create(:user) }

      let(:resource) { create(:issue, project: project) }
      let(:method) { :summarize_comments }
      let(:service_class) { Llm::GenerateSummaryService }

      let_it_be(:default_params) do
        {
          category: described_class.to_s,
          action: 'execute_llm_method',
          property: 'success',
          label: 'summarize_comments',
          user: user,
          namespace: group,
          project: project,
          requestId: 'uuid'
        }
      end

      before do
        allow_next_instance_of(service_class, user, resource, options) do |instance|
          allow(instance).to receive(:execute).and_return(service_response)
        end
      end

      shared_examples 'successful tracking' do
        it 'tracks a snowplow event' do
          subject

          expect_snowplow_event(**expected_params)
        end
      end

      context 'when resource is an issue' do
        let(:expected_params) { default_params }

        it_behaves_like 'successful tracking'
      end

      context 'when resource is a project' do
        let(:resource) { project }
        let(:expected_params) { default_params }

        it_behaves_like 'successful tracking'
      end

      context 'when resource is a group' do
        let(:resource) { group }
        let(:expected_params) { default_params.merge(project: nil) }

        it_behaves_like 'successful tracking'
      end

      context 'when resource is an epic' do
        let(:resource) { epic }
        let(:expected_params) { default_params.merge(project: nil) }

        it_behaves_like 'successful tracking'
      end

      context 'when resource is a user' do
        let(:resource) { user }
        let(:expected_params) { default_params.merge(namespace: nil, project: nil) }

        it_behaves_like 'successful tracking'
      end

      context 'when resource is nil' do
        let(:resource) { nil }
        let(:expected_params) { default_params.merge(namespace: nil, project: nil) }

        it_behaves_like 'successful tracking'
      end

      context 'when service responds with an error' do
        let(:success) { false }
        let(:expected_params) { default_params.merge(property: "error") }

        it_behaves_like 'successful tracking'
      end

      context 'when request ID is nil' do
        let(:request_id) { nil }
        let(:expected_params) { default_params.merge(requestId: nil) }

        it_behaves_like 'successful tracking'
      end
    end
  end
end
