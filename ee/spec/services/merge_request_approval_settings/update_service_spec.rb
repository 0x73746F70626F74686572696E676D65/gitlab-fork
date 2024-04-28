# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestApprovalSettings::UpdateService, feature_category: :code_review_workflow do
  let!(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :in_group, merge_requests_author_approval: true) }
  let_it_be(:user) { create(:user) }

  let(:params) { { allow_author_approval: false } }

  subject(:service) do
    described_class.new(
      container: container,
      current_user: user,
      params: params
    )
  end

  describe 'execute with a Project as container' do
    let(:container) { project }

    context 'user does not have permissions' do
      before do
        allow(service).to receive(:can?).with(user, :admin_merge_request_approval_settings, container).and_return(false)
      end

      it 'responds with an error response', :aggregate_failures do
        response = subject.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Insufficient permissions')
      end

      it 'does not change any of the approval settings' do
        expect { subject.execute }.not_to change { project.attributes }
      end
    end

    context 'user has permissions' do
      before do
        allow(service).to receive(:can?).with(user, :admin_merge_request_approval_settings, container).and_return(true)
      end

      it 'responds with a successful service response', :aggregate_failures do
        response = subject.execute

        expect(response).to be_success
        expect(response.payload.reload.merge_requests_author_approval).to be(false)
        expect(project.reload.merge_requests_author_approval).to be(false)
      end

      context 'run_compliance_standard_checks' do
        let(:params) { { allow_author_approval: false, allow_committer_approval: false } }

        before do
          stub_licensed_features(group_level_compliance_dashboard: true)
        end

        it 'invokes standards adherence workers', :sidekiq_inline, :aggregate_failures do
          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorWorker)
            .to receive(:perform_async).with({ 'project_id' => project.id, 'user_id' => user.id }).and_call_original

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterWorker)
            .to receive(:perform_async).with({ 'project_id' => project.id, 'user_id' => user.id }).and_call_original

          expect(::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker)
            .to receive(:perform_async).with({ 'project_id' => project.id, 'user_id' => user.id }).and_call_original

          response = subject.execute

          expect(response).to be_success

          project_adherence = project.reload.compliance_standards_adherence
                                .for_check_name(:prevent_approval_by_merge_request_author).first

          project_adherence_2 = project.compliance_standards_adherence
                                .for_check_name(:prevent_approval_by_merge_request_committers).first

          project_adherence_3 = project.compliance_standards_adherence
                                  .for_check_name(:at_least_one_non_author_approval).first

          expect(project_adherence.status).to eq("success")
          expect(project_adherence_2.status).to eq("success")
          expect(project_adherence_3.status).to eq("fail")
        end
      end
    end
  end

  describe 'execute with a Group as container' do
    let(:container) { group }
    let(:project) { create(:project, group: group) }

    shared_examples 'call audit changes service' do
      it 'executes GroupMergeRequestApprovalSettingChangesAuditor' do
        expect(Audit::GroupMergeRequestApprovalSettingChangesAuditor).to receive(:new).with(user,
          instance_of(GroupMergeRequestApprovalSetting), params).and_call_original

        subject.execute
      end
    end

    context 'user does not have permissions' do
      before do
        allow(service).to receive(:can?).with(user, :admin_merge_request_approval_settings, group).and_return(false)
      end

      it 'responds with an error response', :aggregate_failures do
        response = subject.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Insufficient permissions')
      end
    end

    context 'user has permissions' do
      before do
        allow(service).to receive(:can?).with(user, :admin_merge_request_approval_settings, group).and_return(true)
      end

      it 'creates a new setting' do
        expect { subject.execute }
          .to change { group.group_merge_request_approval_setting }
          .from(nil).to(be_instance_of(GroupMergeRequestApprovalSetting))
      end

      it 'responds with a successful service response', :aggregate_failures do
        response = subject.execute

        expect(response).to be_success
        expect(response.payload.allow_author_approval).to be(false)
      end

      context 'run_compliance_standard_checks' do
        let(:params) { { allow_author_approval: false, allow_committer_approval: false } }

        before do
          stub_licensed_features(group_level_compliance_dashboard: true)
        end

        it 'invokes GroupWorkers', :sidekiq_inline do
          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorGroupWorker)
            .to receive(:perform_async).with({ 'group_id' => group.id, 'user_id' => user.id }).and_call_original

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterGroupWorker)
            .to receive(:perform_async).with({ 'group_id' => group.id, 'user_id' => user.id }).and_call_original

          expect(::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalGroupWorker)
            .to receive(:perform_async).with({ 'group_id' => group.id, 'user_id' => user.id }).and_call_original

          response = subject.execute

          expect(response).to be_success
        end
      end

      it_behaves_like 'call audit changes service'

      context 'when group has an existing setting' do
        let_it_be(:group) { create(:group) }
        let_it_be(:existing_setting) { create(:group_merge_request_approval_setting, group: group) }

        it 'does not create a new setting' do
          expect { subject.execute }.not_to change { GroupMergeRequestApprovalSetting.count }
        end

        it 'responds with a successful service response', :aggregate_failures do
          response = subject.execute

          expect(response).to be_success
          expect(response.payload.allow_author_approval).to be(false)
        end

        it_behaves_like 'call audit changes service'
      end

      context 'when saving fails' do
        let(:params) { { allow_author_approval: nil } }

        it 'responds with an error service response', :aggregate_failures do
          response = subject.execute

          expect(response).to be_error
          expect(response.message).to eq(allow_author_approval: ['must be a boolean value'])
        end
      end
    end
  end
end
