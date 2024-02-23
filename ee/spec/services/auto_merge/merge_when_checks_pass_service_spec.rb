# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::MergeWhenChecksPassService, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  include_context 'for auto_merge strategy context'

  let(:approval_rule) do
    create(:approval_merge_request_rule, merge_request: mr_merge_if_green_enabled,
      approvals_required: approvals_required)
  end

  describe '#available_for?' do
    subject { service.available_for?(mr_merge_if_green_enabled) }

    let_it_be(:approver) { create(:user) }
    let(:feature_flag) { true }
    let(:draft_status) { true }
    let(:blocked_status) { true }
    let(:discussions_status) { true }
    let(:additional_feature_flag) { true }
    let(:pipeline_status) { :running }
    let(:approvals_required) { 1 }

    before do
      create(:ci_pipeline, pipeline_status,
        ref: mr_merge_if_green_enabled.source_branch,
        sha: mr_merge_if_green_enabled.diff_head_sha,
        project: mr_merge_if_green_enabled.source_project)
      mr_merge_if_green_enabled.update_head_pipeline

      approval_rule.users << approver
      stub_feature_flags(merge_when_checks_pass: feature_flag,
        additional_merge_when_checks_ready: additional_feature_flag)
      mr_merge_if_green_enabled.update!(title: 'Draft: check') if draft_status
      allow(mr_merge_if_green_enabled).to receive(:merge_blocked_by_other_mrs?).and_return(blocked_status)
      allow(mr_merge_if_green_enabled).to receive(:mergeable_discussions_state?).and_return(discussions_status)
    end

    where(:pipeline_status, :approvals_required, :draft_status, :blocked_status, :discussions_status,
      :external_checks_pass, :additional_feature_flag, :result) do
      :running | 0 | true | true | false | false | true | true
      :running | 0 | false | false | true | true | true | true
      :success | 0 | false | false | true | true | true | false
      :success | 0 | true | true | false | false | true | true
      :success | 0 | true | true | true | false | false | false
      :running | 1 | true | true | false | false | true | true
      :success | 1 | true | true | false | false | true | true
      :success | 1 | false | false | true | true | true | true
      :running | 1 | false | false | true | true | true | true
    end

    with_them do
      it { is_expected.to eq result }
    end

    context 'when feature flags merge_when_checks_pass and additional_merge_when_checks_ready are disabled"' do
      let(:additional_feature_flag) { false }
      let(:feature_flag) { false }

      where(:pipeline_status, :approvals_required, :draft_status, :blocked_status, :discussions_status,
        :external_checks_pass, :result) do
        :running | 0 | true  | true | false | false | false
        :success | 0 | false | false | true | true | false
        :running | 1 | false | false | true | true | false
        :success | 1 | true | false | true | false | false
      end

      with_them do
        it { is_expected.to eq result }
      end
    end

    context 'when the user does not have permission to merge' do
      let(:pipeline_status) { :running }
      let(:approvals_required) { 0 }

      before do
        allow(mr_merge_if_green_enabled).to receive(:can_be_merged_by?).and_return(false)
      end

      it { is_expected.to eq false }
    end

    context 'when there is an open MR dependency and "additional_merge_when_checks_ready" is disabled' do
      let(:pipeline_status) { :running }
      let(:approvals_required) { 0 }

      before do
        stub_feature_flags(additional_merge_when_checks_ready: false)
        stub_licensed_features(blocking_merge_requests: true)
        create(:merge_request_block, blocked_merge_request: mr_merge_if_green_enabled)
      end

      it { is_expected.to eq false }
    end

    context 'when merge trains are enabled' do
      before do
        allow(mr_merge_if_green_enabled.project).to receive(:merge_trains_enabled?).and_return(true)
      end

      it { is_expected.to eq false }
    end
  end

  describe "#execute" do
    it_behaves_like 'auto_merge service #execute' do
      let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS }
      let(:expected_note) do
        "enabled an automatic merge when all merge checks for #{pipeline.sha} pass"
      end

      before do
        merge_request.update!(merge_params: { sha: pipeline.sha })
      end
    end

    context 'when no pipeline exists' do
      it_behaves_like 'auto_merge service #execute' do
        let(:pipeline) { nil }
        let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS }
        let(:expected_note) do
          "enabled an automatic merge when all merge checks for 123456 pass"
        end

        before do
          merge_request.update!(merge_params: { sha: "123456" })
        end
      end
    end
  end

  describe "#process" do
    context 'when the merge request is mergable' do
      it 'calls the merge worker' do
        expect(mr_merge_if_green_enabled)
          .to receive(:merge_async)
          .with(mr_merge_if_green_enabled.merge_user_id, mr_merge_if_green_enabled.merge_params)

        service.process(mr_merge_if_green_enabled)
      end
    end

    context 'when the merge request is not mergeable' do
      it 'does not call the merge worker' do
        expect(mr_merge_if_green_enabled).to receive(:mergeable?).and_return(false)
        expect(mr_merge_if_green_enabled).not_to receive(:merge_async)

        service.process(mr_merge_if_green_enabled)
      end
    end
  end

  describe '#cancel' do
    it_behaves_like 'auto_merge service #cancel'
  end

  describe '#abort' do
    it_behaves_like 'auto_merge service #abort'
  end
end
