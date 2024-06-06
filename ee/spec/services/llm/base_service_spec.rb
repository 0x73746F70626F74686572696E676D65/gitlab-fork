# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::BaseService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  let(:options) { {} }

  subject { described_class.new(user, resource, options) }

  shared_examples 'returns an error' do
    it 'returns an error' do
      result = subject.execute

      expect(result).to be_error
      expect(result.message).to eq(described_class::INVALID_MESSAGE)
    end
  end

  shared_examples 'returns a missing resource error' do
    it 'returns a missing resource error' do
      result = subject.execute

      expect(result).to be_error
      expect(result.message).to eq(described_class::MISSING_RESOURCE_ID_MESSAGE)
    end
  end

  shared_examples 'raises a NotImplementedError' do
    it 'raises a NotImplementedError' do
      expect { subject.execute }.to raise_error(NotImplementedError)
    end
  end

  shared_examples 'success when implemented' do
    subject do
      Class.new(described_class) do
        def perform
          schedule_completion_worker
        end

        def ai_action
          :test
        end
      end.new(user, resource, options)
    end

    it_behaves_like 'schedules completion worker' do
      let(:action_name) { :test }
    end
  end

  shared_examples 'success when implemented with slash command' do
    subject do
      Class.new(described_class) do
        def perform
          schedule_completion_worker
        end
      end.new(user, resource, options)
    end

    it_behaves_like 'schedules completion worker' do
      let(:action_name) { "/explain def" }
    end
  end

  shared_examples 'success when implemented with invalid slash command' do
    subject do
      Class.new(described_class) do
        def perform
          schedule_completion_worker
        end
      end.new(user, resource, options)
    end

    it_behaves_like 'schedules completion worker' do
      let(:action_name) { "/where can credentials be set" }
    end
  end

  shared_examples 'authorizing a resource' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    before do
      allow(Gitlab::Llm::Utils::Authorizer).to receive(:resource).with(resource: resource, user: user)
        .and_return(authorizer_response)
    end

    context 'when the resource is authorized' do
      let(:allowed) { true }

      it_behaves_like 'success when implemented'
    end

    context 'when the resource is not authorized' do
      let(:allowed) { false }

      it_behaves_like 'returns an error'
    end
  end

  context 'for SaaS instance', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:resource) { create(:issue, project: project) }

    context 'when user does not have access to AI features' do
      it_behaves_like 'returns an error'
    end

    context 'when user has access to AI features as a non-member' do
      let_it_be(:resource) { create(:issue, project: project) }

      before do
        allow(user).to receive(:any_group_with_ai_available?).and_return(true)
      end

      it_behaves_like 'authorizing a resource'
    end

    context 'when user has access as a member' do
      before do
        group.add_developer(user)
      end

      context 'when ai_global_switch feature flag is not enabled' do
        before do
          stub_feature_flags(ai_global_switch: false)
        end

        it_behaves_like 'returns an error'
      end

      context 'when experimental features are disabled for the group' do
        include_context 'with experiment features disabled for group'

        it_behaves_like 'returns an error'
      end

      context 'when ai features are enabled' do
        before do
          stub_feature_flags(require_resource_id: false)
        end

        include_context 'with ai features enabled for group'

        it_behaves_like 'raises a NotImplementedError'

        context 'when resource is an issue' do
          let_it_be(:resource) { create(:issue, project: project) }

          it_behaves_like 'authorizing a resource'
        end

        context 'when resource is a user' do
          let_it_be(:resource) { user }

          it_behaves_like 'authorizing a resource'
        end

        context 'when resource is nil' do
          let_it_be(:resource) { nil }

          it_behaves_like 'success when implemented'
        end

        context 'when require_resource_id FF is enabled' do
          context 'when resource is missing' do
            let(:resource) { nil }
            let(:options) { { ai_action: "/explain def" } }

            before do
              stub_feature_flags(require_resource_id: true)
            end

            it_behaves_like 'returns a missing resource error'
          end

          context 'when non slash command request starts with a slash' do
            let(:resource) { nil }
            let(:options) { { ai_action: "/where can credentials be set" } }

            before do
              stub_feature_flags(require_resource_id: true)
            end

            it_behaves_like 'success when implemented with invalid slash command'
          end

          context 'when non slash command request is received' do
            let(:resource) { nil }

            before do
              stub_feature_flags(require_resource_id: true)
            end

            it_behaves_like 'success when implemented'
          end
        end

        context 'when resource is missing and require_resource_id FF is disabled, slash command request ' do
          let(:resource) { nil }
          let(:options) { { ai_action: "/explain def" } }

          it_behaves_like 'success when implemented with slash command'
        end
      end
    end
  end

  context 'for self-managed instance' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:resource) { create(:issue, project: project) }

    context 'when user has no access' do
      it_behaves_like 'returns an error'
    end

    context 'when user has access' do
      before do
        project.add_developer(user)
        group.add_developer(user)
      end

      it_behaves_like 'authorizing a resource'
    end
  end
end
