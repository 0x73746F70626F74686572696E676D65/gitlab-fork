# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Action, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:resource, reload: true) { create(:issue) }
  let(:resource_id) { resource.to_gid.to_s }
  let(:request_id) { 'uuid' }
  let(:headers) { { "Referer" => "foobar", "User-Agent" => "user-agent" } }
  let(:request) { instance_double(ActionDispatch::Request, headers: headers) }
  let(:context) { { current_user: user, request: request } }
  let(:expected_options) { { user_agent: "user-agent" } }

  subject(:mutation) { described_class.new(object: nil, context: context, field: nil) }

  describe '#ready?' do
    let(:arguments) do
      { summarize_comments: { resource_id: resource_id }, client_subscription_id: 'id' }
    end

    it { is_expected.to be_ready(**arguments) }

    context 'when no arguments are set' do
      let(:arguments) { {} }

      it 'raises error' do
        expect { subject.ready?(**arguments) }
          .to raise_error(
            Gitlab::Graphql::Errors::ArgumentError,
            described_class::MUTUALLY_EXCLUSIVE_ARGUMENTS_ERROR
          )
      end
    end
  end

  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end

  describe '#resolve' do
    subject do
      mutation.resolve(**input)
    end

    shared_examples_for 'an AI action when feature flag disabled' do |feature_flag = :ai_global_switch|
      context 'when the user can perform AI action' do
        before do
          resource.project.add_developer(user)
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(feature_flag => false)
          end

          it 'raises error' do
            expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end
    end

    shared_examples_for 'an AI action' do
      context 'when resource_id is not for an Ai::Model' do
        let(:resource_id) { "gid://gitlab/Note/#{resource.id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
        end
      end

      context 'when resource cannot be found' do
        let(:resource_id) { "gid://gitlab/Issue/#{non_existing_record_id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the action is called too many times' do
        it 'raises error' do
          expect(Gitlab::ApplicationRateLimiter).to(
            receive(:throttled?).with(:ai_action, scope: [user]).and_return(true)
          )

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /too many times/)
        end
      end

      context 'when user cannot read resource' do
        it 'raises error' do
          allow(Ability)
            .to receive(:allowed?)
            .with(user, "read_#{resource.to_ability_name}", resource)
            .and_return(false)

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user can perform AI action' do
        context 'when user is not a member who can view the resource' do
          before do
            allow(Ability)
              .to receive(:allowed?)
              .with(user, "read_#{resource.to_ability_name}", resource)
              .and_return(true)
          end

          it 'calls Llm::ExecuteMethodService' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              resource,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.success(
                  payload: {
                    ai_message: build(:ai_message, request_id: request_id)
                  }))
            end

            expect(subject[:errors]).to be_empty
            expect(subject[:request_id]).to eq(request_id)
          end
        end

        context 'when user is a member who can view the resource' do
          before do
            resource.project.add_developer(user)
          end

          it 'calls Llm::ExecuteMethodService' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              resource,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.success(
                  payload: {
                    ai_message: build(:ai_message, request_id: request_id)
                  }))
            end

            expect(subject[:errors]).to be_empty
            expect(subject[:request_id]).to eq(request_id)
          end

          context 'when Llm::ExecuteMethodService errors out' do
            it 'returns errors' do
              expect_next_instance_of(
                Llm::ExecuteMethodService,
                user,
                resource,
                expected_method,
                expected_options
              ) do |svc|
                expect(svc)
                  .to receive(:execute)
                  .and_return(ServiceResponse.error(message: 'error'))
              end

              expect(subject[:errors]).to eq(['error'])
              expect(subject[:request_id]).to be_nil
            end
          end

          context 'when resource is null' do
            let(:resource_id) { nil }

            it 'calls Llm::ExecuteMethodService' do
              expect_next_instance_of(
                Llm::ExecuteMethodService,
                user,
                nil,
                expected_method,
                expected_options
              ) do |svc|
                expect(svc)
                  .to receive(:execute)
                  .and_return(ServiceResponse.success(
                    payload: {
                      ai_message: build(:ai_message, request_id: request_id)
                    }))
              end

              expect(subject[:errors]).to be_empty
              expect(subject[:request_id]).to eq(request_id)
            end
          end
        end
      end
    end

    context 'when chat input is set ' do
      let_it_be(:project) { create(:project, :repository, developers: user) }
      let_it_be(:issue) { create(:issue, project: project) }
      let(:input) { { chat: { resource_id: resource_id } } }
      let(:expected_method) { :chat }
      let(:expected_options) { { referer_url: "foobar", user_agent: "user-agent" } }

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled', :ai_duo_chat_switch
    end

    context 'when summarize_comments input is set' do
      let(:input) { { summarize_comments: { resource_id: resource_id } } }
      let(:expected_method) { :summarize_comments }
      let(:expected_options) { { user_agent: "user-agent" } }

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end

    context 'when client_subscription_id input is set' do
      let(:input) { { summarize_comments: { resource_id: resource_id }, client_subscription_id: 'id' } }
      let(:expected_method) { :summarize_comments }
      let(:expected_options) { { client_subscription_id: 'id', user_agent: 'user-agent' } }

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end

    context 'when input is set for feature in self-managed' do
      let(:input) { { summarize_comments: { resource_id: resource_id }, client_subscription_id: 'id' } }
      let(:expected_method) { :summarize_comments }
      let(:expected_options) { { client_subscription_id: 'id', user_agent: 'user-agent' } }

      before do
        stub_const(
          "::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST",
          summarize_comments: {
            self_managed: true,
            execute_method: ::Llm::GenerateSummaryService,
            internal: false
          }
        )
      end

      it_behaves_like 'an AI action'
    end

    context 'when explain_vulnerability input is set', :saas do
      before do
        allow(Ability)
            .to receive(:allowed?)
            .and_call_original

        allow(Ability)
            .to receive(:allowed?)
            .with(user, :explain_vulnerability, user)
            .and_return(true)
      end

      let(:input) { { explain_vulnerability: { resource_id: resource_id, include_source_code: true } } }
      let(:expected_method) { :explain_vulnerability }
      let(:expected_options) { { include_source_code: true, user_agent: 'user-agent' } }

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end
  end
end
