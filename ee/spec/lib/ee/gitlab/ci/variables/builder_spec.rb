# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Builder, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:job) do
    create(:ci_build,
      :with_deployment,
      name: 'rspec:test 1',
      pipeline: pipeline,
      user: user,
      yaml_variables: [{ key: 'YAML_VARIABLE', value: 'value' }],
      environment: 'review/$CI_COMMIT_REF_NAME',
      options: {
        environment: {
          name: 'review/$CI_COMMIT_REF_NAME',
          action: 'prepare',
          deployment_tier: 'testing',
          url: 'https://gitlab.com'
        }
      }
    )
  end

  let(:builder) { described_class.new(pipeline) }

  describe '#scoped_variables' do
    let(:environment_name) { job.expanded_environment_name }
    let(:dependencies) { true }

    subject(:scoped_variables) do
      builder.scoped_variables(job, environment: environment_name, dependencies: dependencies)
    end

    it { is_expected.to be_instance_of(Gitlab::Ci::Variables::Collection) }

    describe 'variables ordering' do
      def var(name, value)
        { key: name, value: value.to_s, public: true, masked: false }
      end

      before do
        pipeline_variables_builder = instance_double(
          ::Gitlab::Ci::Variables::Builder::Pipeline,
          predefined_variables: [var('C', 3), var('D', 3)]
        )
        scan_execution_policies_variables_builder = instance_double(
          ::EE::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies, variables: [var('Q', 16), var('R', 16)]
        )

        allow(builder).to receive(:predefined_variables) { [var('A', 1), var('B', 1)] }
        allow(pipeline.project).to receive(:predefined_variables) { [var('B', 2), var('C', 2)] }
        allow(builder).to receive(:pipeline_variables_builder) { pipeline_variables_builder }
        allow(pipeline).to receive(:predefined_variables) { [var('C', 3), var('D', 3)] }
        allow(job).to receive(:runner) do
          instance_double(::Ci::Runner, predefined_variables: [var('D', 4), var('E', 4)])
        end
        allow(builder).to receive(:kubernetes_variables) { [var('E', 5), var('F', 5)] }
        allow(job).to receive(:yaml_variables) { [var('G', 7), var('H', 7)] }
        allow(builder).to receive(:user_variables) { [var('H', 8), var('I', 8)] }
        allow(job).to receive(:dependency_variables) { [var('I', 9), var('J', 9)] }
        allow(builder).to receive(:secret_instance_variables) { [var('J', 10), var('K', 10)] }
        allow(builder).to receive(:secret_group_variables) { [var('K', 11), var('L', 11)] }
        allow(builder).to receive(:secret_project_variables) { [var('L', 12), var('M', 12)] }
        allow(pipeline).to receive(:variables) { [var('M', 13), var('N', 13)] }
        allow(pipeline).to receive(:pipeline_schedule) do
          instance_double(::Ci::PipelineSchedule, job_variables: [var('N', 14), var('O', 14)])
        end
        allow(builder).to receive(:release_variables) { [var('P', 15), var('Q', 15)] }
        allow(builder).to receive(:scan_execution_policies_variables_builder) do
          scan_execution_policies_variables_builder
        end
      end

      it 'returns variables in order depending on resource hierarchy' do
        expect(scoped_variables.to_runner_variables).to eq(
          [var('A', 1), var('B', 1),
            var('B', 2), var('C', 2),
            var('C', 3), var('D', 3),
            var('D', 4), var('E', 4),
            var('E', 5), var('F', 5),
            var('G', 7), var('H', 7),
            var('H', 8), var('I', 8),
            var('I', 9), var('J', 9),
            var('J', 10), var('K', 10),
            var('K', 11), var('L', 11),
            var('L', 12), var('M', 12),
            var('M', 13), var('N', 13),
            var('N', 14), var('O', 14),
            var('P', 15), var('Q', 15),
            var('Q', 16), var('R', 16)])
      end

      it 'overrides duplicate keys depending on resource hierarchy' do
        expect(scoped_variables.to_hash).to match(
          'A' => '1', 'B' => '2',
          'C' => '3', 'D' => '4',
          'E' => '5', 'F' => '5',
          'G' => '7', 'H' => '8',
          'I' => '9', 'J' => '10',
          'K' => '11', 'L' => '12',
          'M' => '13', 'N' => '14',
          'O' => '14', 'P' => '15',
          'Q' => '16', 'R' => '16')
      end

      context 'when job is marked as a policy job' do
        before do
          job.set_execution_policy_job!
        end

        it 're-applies yaml_variables with the highest precedence' do
          expect(scoped_variables.to_runner_variables).to eq(
            [var('A', 1), var('B', 1),
              var('B', 2), var('C', 2),
              var('C', 3), var('D', 3),
              var('D', 4), var('E', 4),
              var('E', 5), var('F', 5),
              var('G', 7), var('H', 7),
              var('H', 8), var('I', 8),
              var('I', 9), var('J', 9),
              var('J', 10), var('K', 10),
              var('K', 11), var('L', 11),
              var('L', 12), var('M', 12),
              var('M', 13), var('N', 13),
              var('N', 14), var('O', 14),
              var('P', 15), var('Q', 15),
              var('Q', 16), var('R', 16),
              var('G', 7), var('H', 7)])
        end

        it 'overrides duplicate keys depending on resource hierarchy' do
          expect(scoped_variables.to_hash).to match(
            'A' => '1', 'B' => '2',
            'C' => '3', 'D' => '4',
            'E' => '5', 'F' => '5',
            'G' => '7', 'H' => '7',
            'I' => '9', 'J' => '10',
            'K' => '11', 'L' => '12',
            'M' => '13', 'N' => '14',
            'O' => '14', 'P' => '15',
            'Q' => '16', 'R' => '16')
        end

        context 'when feature flag "pipeline_execution_policy_type" is disabled' do
          before do
            stub_feature_flags(pipeline_execution_policy_type: false)
          end

          it 'keeps the original precedence' do
            expect(scoped_variables.to_runner_variables).to eq(
              [var('A', 1), var('B', 1),
                var('B', 2), var('C', 2),
                var('C', 3), var('D', 3),
                var('D', 4), var('E', 4),
                var('E', 5), var('F', 5),
                var('G', 7), var('H', 7),
                var('H', 8), var('I', 8),
                var('I', 9), var('J', 9),
                var('J', 10), var('K', 10),
                var('K', 11), var('L', 11),
                var('L', 12), var('M', 12),
                var('M', 13), var('N', 13),
                var('N', 14), var('O', 14),
                var('P', 15), var('Q', 15),
                var('Q', 16), var('R', 16)])
          end

          it 'does not override keys with job yaml_variables' do
            expect(scoped_variables.to_hash).to match(
              'A' => '1', 'B' => '2',
              'C' => '3', 'D' => '4',
              'E' => '5', 'F' => '5',
              'G' => '7', 'H' => '8',
              'I' => '9', 'J' => '10',
              'K' => '11', 'L' => '12',
              'M' => '13', 'N' => '14',
              'O' => '14', 'P' => '15',
              'Q' => '16', 'R' => '16')
          end
        end
      end
    end

    context 'with policies_variables' do
      let(:policies_variables) do
        [
          { key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true' },
          { key: 'OTHER', value: 'some value' }
        ]
      end

      it 'calls policies builder' do
        expect_next_instance_of(EE::Gitlab::Ci::Variables::Builder::ScanExecutionPolicies) do |policies_builder|
          expect(policies_builder).to receive(:variables)
                                        .with(job)
                                        .and_return(policies_variables)
        end
        expect(scoped_variables.to_hash).to include('SECRET_DETECTION_HISTORIC_SCAN' => 'true', 'OTHER' => 'some value')
      end
    end
  end
end
