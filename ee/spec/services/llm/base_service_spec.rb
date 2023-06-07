# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::BaseService, :saas, feature_category: :no_category do # rubocop: disable RSpec/InvalidFeatureCategory
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:resource) { create(:issue, project: project) }
  let(:options) { {} }

  subject { described_class.new(user, resource, options) }

  shared_examples 'returns an error' do
    it 'returns an error' do
      result = subject.execute

      expect(result).to be_error
      expect(result.message).to eq(described_class::INVALID_MESSAGE)
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
          worker_perform(user, resource, :test, {})
        end
      end.new(user, resource, options)
    end

    it 'runs the worker' do
      expect(SecureRandom).to receive(:uuid).twice.and_return('uuid')
      expect(::Llm::CompletionWorker)
        .to receive(:perform_async)
        .with(user.id, expected_resource_id, expected_resource_class, :test, { request_id: 'uuid' })

      expect(subject.execute).to be_success
    end
  end

  context 'when user has no access' do
    it_behaves_like 'returns an error'
  end

  context 'when user has access' do
    before do
      project.add_developer(user)
      group.add_developer(user)
    end

    it_behaves_like 'raises a NotImplementedError'

    context 'when ai integration is not enabled' do
      before do
        stub_feature_flags(openai_experimentation: false)
      end

      it_behaves_like 'returns an error'
    end

    context 'when ai features are enabled' do
      let(:expected_resource_id) { resource.id }
      let(:expected_resource_class) { resource.class.name.to_s }

      include_context 'with ai features enabled for group'

      it_behaves_like 'raises a NotImplementedError'

      context 'when resource is an issue' do
        let_it_be(:resource) { create(:issue, project: project) }

        it_behaves_like 'success when implemented'
      end

      context 'when resource is a user' do
        let_it_be(:resource) { user }

        it_behaves_like 'success when implemented'
      end

      context 'when resource is not the current user' do
        let_it_be(:resource) { create(:user) }

        it_behaves_like 'returns an error'
      end
    end

    context 'when resource is a user' do
      let_it_be(:resource) { user }

      context 'when third party features are disabled' do
        include_context 'with third party features disabled for group'

        it_behaves_like 'returns an error'
      end

      context 'when experiment features are disabled' do
        include_context 'with experiment features disabled for group'

        it_behaves_like 'returns an error'
      end
    end
  end
end
