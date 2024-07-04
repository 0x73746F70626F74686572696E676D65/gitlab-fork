# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let(:pipeline) { build(:ci_pipeline, project: project) }

  let(:pipeline_execution_policies) { nil }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      pipeline_execution_policies: pipeline_execution_policies
    )
  end

  let(:step) { described_class.new(pipeline, command) }
  let(:yaml_processor_result) { instance_double(Gitlab::Ci::YamlProcessor::Result, clear_jobs!: true) }
  let(:workflow_rules_variables) { { 'VAR1' => 'val2', 'VAR2' => 3 } }

  before do
    allow(command).to receive(:yaml_processor_result).and_return(yaml_processor_result)
  end

  describe '#perform!' do
    shared_examples_for 'pipeline not skipped' do
      it 'continues the pipeline processing chain' do
        expect(step.break?).to be false
      end

      it 'does not skip the pipeline' do
        expect(pipeline).not_to be_persisted
        expect(pipeline).not_to be_skipped
      end

      it 'attaches no errors' do
        expect(pipeline.errors).to be_empty
      end

      it 'saves workflow_rules_result' do
        expect(command.workflow_rules_result.variables).to eq({ 'VAR1' => 'val2', 'VAR2' => 3 })
      end

      it 'does not set a failure reason' do
        expect(pipeline).not_to be_filtered_by_workflow_rules
      end
    end

    context 'when pipeline has not been skipped by workflow configuration' do
      before do
        allow(step).to receive(:workflow_rules_result)
          .and_return(instance_double(Gitlab::Ci::Build::Rules::Result,
            pass?: true, variables: workflow_rules_variables))

        step.perform!
      end

      it_behaves_like 'pipeline not skipped'

      it 'does not clear the jobs from the main pipeline in the yaml_processor_result' do
        expect(yaml_processor_result).not_to receive(:clear_jobs!)

        step.perform!
      end
    end

    context 'when pipeline has been skipped by workflow configuration' do
      before do
        allow(step).to receive(:workflow_rules_result)
                         .and_return(
                           instance_double(Gitlab::Ci::Build::Rules::Result,
                             pass?: false, variables: workflow_rules_variables))
      end

      context 'when execution policy pipelines are empty' do
        before do
          step.perform!
        end

        it 'does not save the pipeline' do
          expect(pipeline).not_to be_persisted
        end

        it 'breaks the chain' do
          expect(step.break?).to be true
        end

        it 'attaches an error to the pipeline' do
          expect(pipeline.errors[:base]).to include('Pipeline filtered out by workflow rules.')
        end

        it 'saves workflow_rules_result' do
          expect(command.workflow_rules_result.variables).to eq(workflow_rules_variables)
        end

        it 'sets the failure reason', :aggregate_failures do
          expect(pipeline).to be_failed
          expect(pipeline).to be_filtered_by_workflow_rules
        end
      end

      context 'when pipeline_execution_policies are present' do
        let(:pipeline_execution_policies) do
          [build(:ci_pipeline_execution_policy, pipeline: build(:ci_pipeline, project: project, user: user))]
        end

        before do
          step.perform!
        end

        it_behaves_like 'pipeline not skipped'

        it 'clears the jobs from the main pipeline in the yaml_processor_result' do
          expect(yaml_processor_result).to receive(:clear_jobs!)

          step.perform!
        end
      end
    end
  end
end
