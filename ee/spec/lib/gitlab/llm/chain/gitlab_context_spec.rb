# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::GitlabContext, :saas, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:project) { create(:project, group: group) }
  let(:resource) { nil }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }

  subject(:context) do
    described_class.new(current_user: user, container: nil, resource: resource, ai_request: ai_request,
      agent_version: instance_double(Ai::AgentVersion))
  end

  before_all do
    group.add_reporter(user)
  end

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  describe '#current_page_type' do
    let(:resource) { create(:issue, project: project) }

    it 'delegates to ai resource' do
      expect(context.current_page_type).to eq("issue")
    end
  end

  describe '#resource_serialized' do
    let(:content_limit) { 500 }

    context 'with an authorized, serializable resource' do
      let(:resource) { create(:issue, project: project) }
      let(:resource_xml) do
        Ai::AiResource::Issue.new(resource).serialize_for_ai(user: user, content_limit: content_limit)
          .to_xml(root: :root, skip_types: true, skip_instruct: true)
      end

      let(:resource2) { create(:issue, project: project) }
      let(:resource_xml2) do
        Ai::AiResource::Issue.new(resource2).serialize_for_ai(user: user, content_limit: content_limit)
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

        context.resource = resource2

        # Do not cache value
        expect(context.resource_serialized(content_limit: content_limit)).to eq(resource_xml2)
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

  describe '#current_page_short_description' do
    context 'with an unauthorized resource' do
      let(:resource) { create(:issue) }

      it 'returns nil' do
        expect(context.current_page_short_description).to be_nil
      end
    end

    context 'with an authorized resource' do
      let(:resource) { create(:issue, project: project) }

      it 'returns short description of issue' do
        expect(context.current_page_short_description).to include("The title of the issue is '#{resource.title}'.")
      end
    end
  end
end
