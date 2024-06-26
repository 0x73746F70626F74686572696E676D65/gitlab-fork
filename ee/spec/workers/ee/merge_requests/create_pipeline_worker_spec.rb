# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreatePipelineWorker, "#execute", feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let(:worker) { Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker }

  subject(:perform) { described_class.new.perform(project.id, project.owner.id, merge_request.id) }

  before do
    stub_licensed_features(security_orchestration_policies: true)

    allow(merge_request).to receive(:diff_head_pipeline).and_return(pipeline)

    allow_next_found_instance_of(MergeRequest) do |project|
      allow(project).to receive(:diff_head_pipeline).and_return(pipeline)
    end
  end

  context "when MR doesn't get a pipeline" do
    let(:pipeline) { nil }

    it "unblocks fail-open rules" do
      expect(worker).to receive(:perform_async).with(merge_request.id)

      perform
    end

    context "without licensed feature" do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it "does not unblock fail-open rules" do
        expect(worker).not_to receive(:perform_async)

        perform
      end
    end
  end

  context "when MR gets a pipeline" do
    let(:pipeline) { create(:ci_pipeline) }

    it "does not unblock fail-open rules" do
      expect(worker).not_to receive(:perform_async)

      perform
    end
  end
end
