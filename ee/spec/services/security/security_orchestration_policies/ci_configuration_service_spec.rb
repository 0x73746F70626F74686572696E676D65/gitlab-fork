# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiConfigurationService,
  feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let(:action) { { scan: scan_type } }
    let(:ci_variables) { { KEY: 'value' } }
    let(:context) { 'context' }
    let(:index) { 0 }
    let(:opts) do
      { allow_restricted_variables_at_policy_level: true, scan_execution_policies_with_latest_templates: true }
    end

    subject(:execute_service) { described_class.new(project).execute(action, ci_variables, context, index) }

    shared_examples_for 'a template scan' do
      it 'configures a template scan' do
        expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Template,
          action,
          ci_variables,
          context,
          index,
          opts
        ) do |instance|
          expect(instance).to receive(:config)
        end

        execute_service
      end

      context 'when allow_restricted_variables_at_policy_level is disabled' do
        before do
          stub_feature_flags(allow_restricted_variables_at_policy_level: false)
        end

        let(:opts) do
          { allow_restricted_variables_at_policy_level: false, scan_execution_policies_with_latest_templates: true }
        end

        it 'configures a template scan with disabled flag' do
          expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Template,
            action,
            ci_variables,
            context,
            index,
            opts
          ) do |instance|
            expect(instance).to receive(:config)
          end

          execute_service
        end
      end

      context 'when scan_execution_policies_with_latest_templates is disabled' do
        before do
          stub_feature_flags(scan_execution_policies_with_latest_templates: false)
          stub_feature_flags(scan_execution_policies_with_latest_templates_group: false)
        end

        let(:opts) do
          { allow_restricted_variables_at_policy_level: true, scan_execution_policies_with_latest_templates: false }
        end

        it 'configures a template scan with disabled flag' do
          expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Template,
            action,
            ci_variables,
            context,
            index,
            opts
          ) do |instance|
            expect(instance).to receive(:config)
          end

          execute_service
        end
      end
    end

    context 'with secret_detection scan action' do
      let(:scan_type) { 'secret_detection' }

      it_behaves_like 'a template scan'
    end

    context 'with container_scanning scan action' do
      let(:scan_type) { 'container_scanning' }

      it_behaves_like 'a template scan'
    end

    context 'with sast scan action' do
      let(:scan_type) { 'sast' }

      it_behaves_like 'a template scan'
    end

    context 'with sast_iac scan action' do
      let(:scan_type) { 'sast_iac' }

      it_behaves_like 'a template scan'
    end

    context 'with dependency_scanning scan action' do
      let(:scan_type) { 'dependency_scanning' }

      it_behaves_like 'a template scan'
    end

    context 'with custom scan action' do
      let(:scan_type) { 'custom' }

      it 'configures a custom scan' do
        expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Custom,
          action,
          ci_variables,
          context,
          index,
          opts
        ) do |instance|
          expect(instance).to receive(:config)
        end

        execute_service
      end
    end

    context 'with unknown action' do
      let(:scan_type) { anything }

      it 'configures a custom scan' do
        expect_next_instance_of(Security::SecurityOrchestrationPolicies::CiAction::Unknown,
          action,
          ci_variables,
          context,
          index,
          opts
        ) do |instance|
          expect(instance).to receive(:config)
        end

        execute_service
      end
    end
  end
end
