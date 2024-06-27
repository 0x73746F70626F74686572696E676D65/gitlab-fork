# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicies::BulkCreateScanResultPolicyService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan_result_policy) { create(:scan_result_policy_read) }
  let(:params) do
    [
      { name: 'ExamplePL/2.1', approval_status: 'denied', scan_result_policy_read: scan_result_policy },
      { name: 'ExamplePL/2.2', approval_status: 'allowed', scan_result_policy_read: scan_result_policy },
      { name: 'MIT', approval_status: 'allowed', scan_result_policy_read: scan_result_policy }
    ]
  end

  subject(:execute_service) { described_class.new(project, params).execute }

  describe '#execute', :aggregate_failures do
    context 'when valid parameters are specified' do
      it 'creates software license policies correctly' do
        result = execute_service
        created_policy = SoftwareLicensePolicy.find_by(result[:software_license_policy].first)

        expect(project.software_license_policies.count).to be(3)
        expect(result[:software_license_policy].count).to eq(3)
        expect(result[:status]).to be(:success)

        expect(created_policy.attributes.with_indifferent_access).to include(
          {
            classification: "denied",
            project_id: project.id,
            scan_result_policy_id: scan_result_policy.id
          }
        )
      end

      it 'inserts custom software licenses and license policies in batches' do
        stub_const("#{described_class.name}::BATCH_SIZE", 2)

        query_recorder = ActiveRecord::QueryRecorder.new { execute_service }

        license_queries = query_recorder.log.count { |q| q.include?('INSERT INTO "custom_software_licenses"') }
        policy_queries = query_recorder.log.count { |q| q.include?('INSERT INTO "software_license_policies"') }

        expect(license_queries).to eq(2)
        expect(policy_queries).to eq(2)
      end

      it 'does not create software licenses' do
        expect { execute_service }.not_to change { SoftwareLicense.count }
      end

      shared_examples 'creates missing licenses as custom software licenses' do |missing_licenses_count|
        it 'creates missing licenses as custom software licenses' do
          expect { execute_service }.to change { Security::CustomSoftwareLicense.count }.by(missing_licenses_count)
        end
      end

      context 'when no software license matching the name exists' do
        it_behaves_like 'creates missing licenses as custom software licenses', 3
      end

      context 'when a software license matching the name exists' do
        before do
          create(:software_license, name: 'MIT', spdx_identifier: 'MIT')
        end

        it_behaves_like 'creates missing licenses as custom software licenses', 2
      end

      context 'when a custom software license matching the name exists in the same project' do
        before do
          create(:custom_software_license, name: 'ExamplePL/2.1', project: project)
        end

        it_behaves_like 'creates missing licenses as custom software licenses', 2
      end

      context 'when a custom software license matching the name exists in the another project' do
        before do
          create(:custom_software_license, name: 'ExamplePL/2.1')
        end

        it_behaves_like 'creates missing licenses as custom software licenses', 3
      end

      context 'when the license name contains whitespaces' do
        let(:params) do
          [{ name: '  NOT MIT   ', approval_status: 'allowed', scan_result_policy_read: scan_result_policy }]
        end

        it 'creates one software license policy with stripped name' do
          result = execute_service
          created_policy = SoftwareLicensePolicy.find_by(result[:software_license_policy].first)

          expect(project.software_license_policies.count).to be(1)
          expect(result[:status]).to be(:success)
          expect(created_policy.custom_software_license.name).to eq('NOT MIT')
        end
      end
    end

    context "when invalid input is provided" do
      let(:params) do
        [
          { name: 'ExamplePL/2.1', scan_result_policy_read: scan_result_policy },
          { name: 'ExamplePL/2.2', approval_status: 'allowed' }
        ]
      end

      it 'does not create invalid records' do
        expect { execute_service }.to change { project.software_license_policies.count }.by(0)
      end

      specify { expect(execute_service[:status]).to be(:success) }
    end
  end
end
