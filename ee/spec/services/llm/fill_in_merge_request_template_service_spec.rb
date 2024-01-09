# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::FillInMergeRequestTemplateService, :saas, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:resource) { create(:project, :public, group: group) }

  let(:fill_in_merge_request_template_enabled) { true }
  let(:current_user) { user }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    before do
      group.add_guest(user)

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability)
        .to receive(:allowed?)
        .with(user, :fill_in_merge_request_template, resource)
        .and_return(fill_in_merge_request_template_enabled)
    end

    subject { described_class.new(current_user, resource, {}).execute }

    it_behaves_like 'schedules completion worker' do
      subject { described_class.new(current_user, resource, options) }

      let(:options) { {} }
      let(:action_name) { :fill_in_merge_request_template }
    end

    context 'when user is not member of project group' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when general feature flag is disabled' do
      before do
        stub_feature_flags(ai_global_switch: false)
      end

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when resource is not a project' do
      let(:resource) { create(:epic, group: group) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when user has no ability to fill_in_merge_request_template' do
      let(:fill_in_merge_request_template_enabled) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end
  end
end
