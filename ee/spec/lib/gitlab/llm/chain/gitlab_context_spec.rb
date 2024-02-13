# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::GitlabContext, :saas, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let(:resource) { nil }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }

  subject(:context) do
    described_class.new(current_user: user, container: nil, resource: resource, ai_request: ai_request,
      agent_version: instance_double(Ai::AgentVersion))
  end

  describe '#resource_serialized' do
    let(:content_limit) { 500 }

    context 'with a serializable resource' do
      let_it_be(:group) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:project) { create(:project, group: group) }
      let(:resource) { create(:issue, project: project) }
      let(:resource_xml) do
        Ai::AiResource::Issue.new(resource).serialize_for_ai(user: user, content_limit: content_limit)
          .to_xml(root: :root, skip_types: true, skip_instruct: true)
      end

      before_all do
        group.add_reporter(user)
      end

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
        stub_licensed_features(ai_chat: true)
        group.namespace_settings.update!(experiment_features_enabled: true)
      end

      it 'returns the AI serialization of the resource' do
        expect(context.resource_serialized(content_limit: content_limit)).to eq(resource_xml)
      end
    end

    context 'with an unauthorized resource' do
      let(:resource) { create(:issue) }

      it 'returns an empty string' do
        expect(context.resource_serialized(content_limit: content_limit)).to eq('')
      end
    end

    context 'with a non-serializable resource' do
      it 'raises an ArgumentError' do
        expect { context.resource_serialized(content_limit: content_limit) }.to raise_error(ArgumentError)
      end
    end
  end
end
