# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Skip, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      ignore_skip_ci: false,
      save_incompleted: true)
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#skipped?' do
    context 'when pipeline has not been skipped' do
      it 'does not break the chain' do
        expect(step.break?).to be false
      end
    end

    context 'when pipeline should be skipped' do
      before do
        allow(pipeline).to receive(:git_commit_message).and_return('commit message [ci skip]')
      end

      it 'breaks the chain' do
        expect(step.break?).to be true
      end

      context 'when pipeline execution policies are present' do
        before do
          command.execution_policy_pipelines = build_list(:ci_empty_pipeline, 1)
        end

        it 'does not break the chain' do
          expect(step.break?).to be false
        end

        context 'when feature flag "pipeline_execution_policy_type" is disabled' do
          before do
            stub_feature_flags(pipeline_execution_policy_type: false)
          end

          it { expect(step.break?).to be true }
        end
      end
    end
  end
end
