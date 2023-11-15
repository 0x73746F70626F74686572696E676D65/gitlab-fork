# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::CompletionWorker, feature_category: :ai_abstraction_layer do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:resource) { create(:issue, project: project) }

    let(:options) { { 'key' => 'value' } }
    let(:ai_action_name) { :summarize_comments }

    let(:prompt_message) do
      build(:ai_message, user: user, resource: resource, ai_action: ai_action_name, request_id: 'uuid')
    end

    subject { described_class.new.perform(described_class.serialize_message(prompt_message), options) }

    it 'calls Llm::Internal::CompletionService and tracks event' do
      expect_next_instance_of(
        Llm::Internal::CompletionService,
        an_object_having_attributes(
          user: user,
          resource: resource,
          request_id: 'uuid',
          ai_action: ai_action_name
        ),
        options
      ) do |instance|
        expect(instance).to receive(:execute)
      end

      subject

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'perform_completion_worker',
        label: ai_action_name.to_s,
        property: 'uuid',
        user: user
      )
    end
  end
end
