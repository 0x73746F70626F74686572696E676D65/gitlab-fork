# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GenerateSummaryService, :saas, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:options) { {} }
  let(:action_name) { :summarize_comments }
  let(:summarize_notes_enabled) { true }
  let(:current_user) { user }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    before do
      group.add_guest(user)

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :summarize_comments, resource).and_return(summarize_notes_enabled)
    end

    subject { described_class.new(current_user, resource, {}).execute }

    shared_examples 'ensures user has the ability to summarize notes' do
      let(:summarize_notes_enabled) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'for an issue' do
      let_it_be(:resource) { create(:issue, project: project) }

      context 'with notes' do
        before do
          create_pair(:note_on_issue, project: resource.project, noteable: resource)
        end

        it_behaves_like 'ensures user has the ability to summarize notes'
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end

    context 'for a work item' do
      let_it_be(:resource) { create(:work_item, project: project) }

      context 'with notes' do
        before do
          create_pair(:note_on_work_item, project: resource.project, noteable: resource)
        end

        it_behaves_like 'ensures user has the ability to summarize notes'
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end

    context 'for an epic' do
      let_it_be(:resource) { create(:epic, group: group) }

      context 'with notes' do
        before do
          stub_licensed_features(epics: true)

          create_pair(:note_on_epic, noteable: resource)
        end

        it_behaves_like 'ensures user has the ability to summarize notes'
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end
  end
end
