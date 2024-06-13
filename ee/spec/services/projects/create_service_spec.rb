# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CreateService, '#execute', feature_category: :groups_and_projects do
  include EE::GeoHelpers

  let_it_be(:user) { create(:user) }
  let(:current_user) { user }
  let(:project_params) { { name: 'GitLab', namespace_id: current_user.namespace.id }.merge(extra_params) }
  let(:extra_params) { {} }

  let(:created_project) { response }

  subject(:response) { described_class.new(current_user, project_params).execute }

  context 'with a built-in template' do
    let(:extra_params) { { template_name: 'rails' } }

    it 'creates a project using the template service' do
      expect(::Projects::CreateFromTemplateService).to receive_message_chain(:new, :execute)

      response
    end
  end

  context 'with a template project ID' do
    let(:extra_params) { { template_project_id: 1 } }

    it 'creates a project using the template service' do
      expect(::Projects::CreateFromTemplateService).to receive_message_chain(:new, :execute)

      response
    end
  end

  context 'with import_type gitlab_custom_project_template' do
    let(:group) do
      create(:group, project_creation_level: project_creation_level) { |g| g.add_developer(user) }
    end

    let(:extra_params) do
      {
        namespace_id: group.id,
        import_type: 'gitlab_custom_project_template',
        import_data: {
          data: {
            template_project_id: 1
          }
        }
      }
    end

    before do
      stub_licensed_features(custom_project_templates: true)
    end

    context 'when the user is allowed to create projects within the namespace' do
      let(:project_creation_level) { Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS }

      it 'creates a project' do
        expect(created_project).to be_persisted
        expect(created_project.import_type).to eq('gitlab_custom_project_template')
      end
    end

    context 'when the user is not allowed to create projects within the namespace' do
      let(:project_creation_level) { Gitlab::Access::MAINTAINER_PROJECT_ACCESS }

      it 'does not create a project' do
        expect(created_project).not_to be_persisted
      end
    end
  end

  context 'with a CI/CD only project' do
    let(:extra_params) { { ci_cd_only: true, import_url: 'http://foo.com' } }

    context 'when CI/CD projects feature is available' do
      before do
        stub_licensed_features(ci_cd_projects: true)
      end

      it 'calls the service to set up CI/CD on the project' do
        expect(CiCd::SetupProject).to receive_message_chain(:new, :execute)

        response
      end
    end

    context 'when CI/CD projects feature is not available' do
      before do
        stub_licensed_features(ci_cd_projects: false)
      end

      it 'does not call the service to set up CI/CD on the project' do
        expect(CiCd::SetupProject).not_to receive(:new)

        response
      end
    end
  end

  context 'with repository_size_limit assignment as Bytes' do
    let_it_be(:admin_user) { create(:admin) }

    context 'when user is an admin and admin mode is enabled', :enable_admin_mode do
      let(:current_user) { admin_user }

      context 'when the param is present' do
        let(:extra_params) { { repository_size_limit: '100' } }

        it 'assign repository_size_limit as Bytes' do
          expect(created_project.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:extra_params) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          expect(created_project.repository_size_limit).to be_nil
        end
      end
    end

    context 'when user is an admin and admin mode is disabled' do
      let(:current_user) { admin_user }
      let(:extra_params) { { repository_size_limit: '100' } }

      it 'assigns a nil value' do
        expect(created_project.repository_size_limit).to be_nil
      end
    end

    context 'when the user is not an admin' do
      let(:extra_params) { { repository_size_limit: '100' } }

      it 'does not assign repository_size_limit' do
        expect(created_project.repository_size_limit).to be_nil
      end
    end
  end

  context 'without repository mirror' do
    let(:extra_params) { { import_url: 'http://foo.com' } }

    before do
      stub_licensed_features(repository_mirrors: true)
    end

    it 'sets the mirror to false' do
      expect(created_project).to be_persisted
      expect(created_project.mirror).to be false
    end
  end

  context 'with repository mirror' do
    let(:extra_params) { { import_url: 'http://foo.com', mirror: true }.merge(more_params) }
    let(:more_params) { {} }

    context 'when licensed' do
      before do
        stub_licensed_features(repository_mirrors: true)
        stub_ee_application_setting(elasticsearch_indexing?: true)
      end

      it 'sets the correct attributes' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(an_instance_of(User))
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(an_instance_of(Project)).twice
        expect(created_project).to be_persisted
        expect(created_project.mirror).to be true
        expect(created_project.mirror_user_id).to eq(user.id)
      end

      context 'with mirror trigger builds' do
        let(:more_params) { { mirror_trigger_builds: true } }

        it 'sets the mirror trigger builds' do
          expect(created_project).to be_persisted
          expect(created_project.mirror_trigger_builds).to be true
        end
      end

      context 'when importing project into a group' do
        let(:group) { create(:group) }
        let(:more_params) { { namespace_id: group.id } }

        context 'without permissions' do
          it 'fails' do
            expect(created_project).not_to be_persisted
            expect(created_project.errors.full_messages).to include('User is not allowed to import projects')
          end
        end

        context 'with sufficient permissions' do
          before do
            group.add_maintainer(user)
          end

          it 'creates a project with a pull mirroring' do
            expect(created_project).to be_persisted
            expect(created_project.mirror).to be true
            expect(created_project.mirror_user_id).to eq(user.id)
            expect(created_project.errors.to_a).to eq([])
          end
        end
      end

      context 'with checks on the namespace' do
        before do
          enable_namespace_license_check!
        end

        context 'when not licensed on a namespace' do
          it 'does not allow enabling mirrors' do
            expect(created_project).to be_persisted
            expect(created_project.mirror).to be_falsey
          end
        end

        context 'when licensed on a namespace', :saas do
          it 'allows enabling mirrors' do
            create(:gitlab_subscription, :ultimate, namespace: user.namespace)

            expect(created_project).to be_persisted
            expect(created_project.mirror).to be_truthy
          end
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(repository_mirrors: false)
      end

      it 'does not set mirror attributes' do
        expect(created_project).to be_persisted
        expect(created_project.mirror).to be false
        expect(created_project.mirror_user_id).to be_nil
      end

      context 'with mirror trigger builds' do
        let(:more_params) { { mirror_trigger_builds: true } }

        it 'sets the mirror trigger builds' do
          expect(created_project).to be_persisted
          expect(created_project.mirror_trigger_builds).to be false
        end
      end
    end
  end

  context 'when inherited_push_rule_for_project is disabled' do
    before do
      stub_feature_flags(inherited_push_rule_for_project: false)
    end

    context 'with sample' do
      let_it_be(:sample) { create(:push_rule_sample) }

      before do
        stub_licensed_features(push_rules: true)
      end

      it 'creates push rule from sample' do
        expect(created_project.push_rule).to(
          have_attributes(
            force_push_regex: sample.force_push_regex,
            deny_delete_tag: sample.deny_delete_tag,
            delete_branch_regex: sample.delete_branch_regex,
            commit_message_regex: sample.commit_message_regex
          )
        )
      end

      it 'creates association between project settings and push rule' do
        project_setting = created_project.push_rule.project.project_setting

        expect(project_setting.push_rule_id).to eq(created_project.push_rule.id)
      end

      context 'when push rules is unlicensed' do
        before do
          stub_licensed_features(push_rules: false)
        end

        it 'ignores the push rule sample' do
          expect(created_project.push_rule).to be_nil
        end
      end
    end

    context 'when there are no push rules' do
      it 'does not create push rule' do
        expect(created_project.push_rule).to be_nil
      end
    end
  end

  context 'for group push rules' do
    before do
      stub_licensed_features(push_rules: true)
      stub_feature_flags(inherited_push_rule_for_project: false)
    end

    context 'for project created within a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: group) }
      let(:extra_params) { { namespace_id: group.id } }

      before_all do
        group.add_owner(user)
      end

      context 'when group has push rule defined' do
        let(:group_push_rule) { create(:push_rule_without_project, force_push_regex: 'testing me') }

        before do
          group.update!(push_rule: group_push_rule)
        end

        it 'does not error if new columns are created since the last schema load' do
          PushRule.connection.execute('ALTER TABLE push_rules ADD COLUMN foobar boolean')

          expect(created_project.push_rule).to be_persisted
        end

        it 'creates push rule from group push rule' do
          project_push_rule = created_project.push_rule

          expect(project_push_rule).to(
            have_attributes(
              force_push_regex: group_push_rule.force_push_regex,
              deny_delete_tag: group_push_rule.deny_delete_tag,
              delete_branch_regex: group_push_rule.delete_branch_regex,
              commit_message_regex: group_push_rule.commit_message_regex,
              is_sample: false
            )
          )
          expect(created_project.project_setting.push_rule_id).to eq(project_push_rule.id)
        end

        context 'with subgroup' do
          let(:extra_params) { { namespace_id: sub_group.id } }

          it 'creates push rule from group push rule' do
            project_push_rule = created_project.push_rule

            expect(project_push_rule).to(
              have_attributes(
                force_push_regex: group_push_rule.force_push_regex,
                deny_delete_tag: group_push_rule.deny_delete_tag,
                delete_branch_regex: group_push_rule.delete_branch_regex,
                commit_message_regex: group_push_rule.commit_message_regex,
                is_sample: false
              )
            )
            expect(created_project.project_setting.push_rule_id).to eq(project_push_rule.id)
          end
        end
      end

      context 'when group does not have push rule defined' do
        let_it_be(:sample) { create(:push_rule_sample) }

        it 'creates push rule from sample' do
          expect(created_project.push_rule).to(
            have_attributes(
              force_push_regex: sample.force_push_regex,
              deny_delete_tag: sample.deny_delete_tag,
              delete_branch_regex: sample.delete_branch_regex,
              commit_message_regex: sample.commit_message_regex
            )
          )
        end

        context 'with subgroup' do
          let(:extra_params) { { namespace_id: sub_group.id } }

          it 'creates push rule from sample in sub-group' do
            expect(created_project.push_rule).to(
              have_attributes(
                force_push_regex: sample.force_push_regex,
                deny_delete_tag: sample.deny_delete_tag,
                delete_branch_regex: sample.delete_branch_regex,
                commit_message_regex: sample.commit_message_regex
              )
            )
          end
        end
      end
    end
  end

  context 'when importing Project by repo URL' do
    context 'and check namespace plan is enabled' do
      let(:extra_params) do
        {
          import_url: 'https://www.gitlab.com/gitlab-org/gitlab-foss',
          visibility_level: Gitlab::VisibilityLevel::PRIVATE,
          mirror: true,
          mirror_trigger_builds: true
        }
      end

      before do
        allow_next_instance_of(EE::Project) do |instance|
          allow(instance).to receive(:add_import_job)
        end

        enable_namespace_license_check!
      end

      it 'creates the project' do
        expect(created_project).to be_persisted
      end
    end
  end

  context 'for audit events' do
    include_examples 'audit event logging' do
      let(:operation) { response }
      let(:fail_condition!) do
        allow(Gitlab::VisibilityLevel).to receive(:allowed_for?).and_return(false)
      end

      let(:event_type) { Projects::CreateService::AUDIT_EVENT_TYPE }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: created_project.id,
          entity_type: 'Project',
          details: {
            author_name: user.name,
            event_name: "project_created",
            target_id: created_project.id,
            target_type: 'Project',
            target_details: created_project.full_path,
            custom_message: Projects::CreateService::AUDIT_EVENT_MESSAGE,
            author_class: user.class.name
          }
        }
      end
    end
  end

  context 'with security policy configuration' do
    context 'with security_policy_target_project_id' do
      let_it_be(:security_policy_target_project) { create(:project) }
      let(:extra_params) { { security_policy_target_project_id: security_policy_target_project.id } }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'creates security policy configuration for the project' do
        expect(::Security::Orchestration::AssignService).to receive_message_chain(:new, :execute)

        response
      end
    end

    context 'with security_policy_target_namespace_id' do
      let_it_be(:security_policy_target_namespace) { create(:namespace) }
      let(:extra_params) { { security_policy_target_namespace_id: security_policy_target_namespace.id } }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'creates security policy configuration for the project' do
        expect(::Security::Orchestration::AssignService).to receive_message_chain(:new, :execute)

        response
      end
    end
  end

  context 'for after create actions' do
    context 'with set_default_compliance_framework' do
      let_it_be(:admin_bot) { create(:user, :admin_bot, :admin) }
      let_it_be(:group, reload: true) { create(:group) }
      let_it_be(:framework) { create(:compliance_framework, namespace: group, name: 'GDPR') }
      let_it_be(:framework_two) { create(:compliance_framework, namespace: group, name: 'HIPAA') }
      let(:extra_params) { { namespace_id: group.id } }

      context 'when default compliance framework is set at the root namespace' do
        before do
          group.add_owner(user)
          group.add_owner(admin_bot)
          group.namespace_settings.update!(default_compliance_framework_id: framework.id)
        end

        it 'sets the default compliance framework for new projects when licensed', :sidekiq_inline do
          stub_licensed_features(custom_compliance_frameworks: true, compliance_framework: true)

          expect(::ComplianceManagement::UpdateDefaultFrameworkWorker).to receive(:perform_async).with(
            user.id,
            anything,
            framework.id
          ).and_call_original

          expect(created_project.compliance_management_frameworks.first.id).to eq(framework.id)
          expect(created_project.compliance_management_frameworks.first.name).to eq('GDPR')
        end

        it 'does not set the default compliance framework for new projects when not licensed' do
          expect(::ComplianceManagement::UpdateDefaultFrameworkWorker).not_to receive(:perform_async)

          expect(created_project.compliance_framework_settings).to eq([])
        end
      end

      context 'when default compliance framework is not set at the root namespace' do
        before do
          group.add_owner(user)
          group.add_owner(admin_bot)
          group.namespace_settings.update!(default_compliance_framework_id: nil)
        end

        it 'does not set the default compliance framework for new projects' do
          stub_licensed_features(custom_compliance_frameworks: true, compliance_framework: true)

          expect(::ComplianceManagement::UpdateDefaultFrameworkWorker).not_to receive(:perform_async)

          expect(created_project.compliance_framework_settings).to eq([])
        end
      end

      context 'when project belongs to a user namespace' do
        it 'does not set the default compliance framework for new projects' do
          stub_licensed_features(custom_compliance_frameworks: true, compliance_framework: true)

          expect(::ComplianceManagement::UpdateDefaultFrameworkWorker).not_to receive(:perform_async)

          expect(created_project.compliance_framework_settings).to eq([])
        end
      end
    end

    describe 'run_compliance_standards_checks' do
      let_it_be(:group, reload: true) { create(:group) }
      let(:extra_params) { { namespace_id: group.id } }

      context 'when project belongs to a group', :sidekiq_inline do
        before do
          group.add_maintainer(user)
        end

        it 'creates compliance standards adherence' do
          stub_licensed_features(group_level_compliance_dashboard: true)

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorWorker)
            .to receive(:perform_async).and_call_original

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterWorker)
            .to receive(:perform_async).and_call_original

          expect(::ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker)
            .to receive(:perform_async).and_call_original

          expect(::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker)
            .to receive(:perform_async).and_call_original

          expect(created_project.compliance_standards_adherence.count).to eq(4)
        end
      end

      context 'when project belongs to a user namespace' do
        it 'does not invoke the workers' do
          stub_licensed_features(group_level_compliance_dashboard: true)

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorWorker)
            .not_to receive(:perform_async)

          expect(::ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterWorker)
            .not_to receive(:perform_async)

          expect(::ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker)
            .not_to receive(:perform_async)

          expect(created_project.compliance_standards_adherence).to be_empty
        end
      end
    end

    context 'with sync scan result policies from group' do
      let_it_be(:group, reload: true) { create(:group) }
      let_it_be(:sub_group, reload: true) { create(:group, parent: group) }
      let(:extra_params) { { namespace_id: sub_group.id } }

      before do
        group.add_owner(user)
      end

      context 'when group has security_orchestration_policy_configuration' do
        let(:policy) { build(:scan_result_policy, branches: []) }
        let_it_be(:group_configuration, reload: true) do
          create(:security_orchestration_policy_configuration, project: nil, namespace: group)
        end

        let_it_be(:sub_group_configuration, reload: true) do
          create(:security_orchestration_policy_configuration, project: nil, namespace: sub_group)
        end

        before do
          allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
            allow(configuration).to receive(:policy_last_updated_by).and_return(user)
          end

          allow_next_instance_of(Repository) do |repository|
            allow(repository).to receive(:blob_data_at).and_return({ scan_result_policy: [policy] }.to_yaml)
          end
        end

        it 'invokes ProcessScanResultPolicyWorker', :sidekiq_inline do
          expect(::Security::ProcessScanResultPolicyWorker).to receive(:perform_async).twice.and_call_original

          expect(created_project.approval_rules.count).to eq(2)
          expect(created_project.approval_rules.map(&:security_orchestration_policy_configuration_id)).to match_array([
            group_configuration.id, sub_group_configuration.id
          ])
        end
      end

      context 'when group does not have security_orchestration_policy_configuration' do
        it 'does not invoke ProcessScanResultPolicyWorker' do
          expect(::Security::ProcessScanResultPolicyWorker).not_to receive(:perform_async)

          response
        end
      end
    end

    context 'with create security policy project bots', feature_category: :security_policy_management do
      let_it_be(:group, reload: true) { create(:group) }
      let_it_be(:sub_group, reload: true) { create(:group, parent: group) }
      let(:extra_params) { { namespace_id: group.id } }

      before do
        group.add_owner(user)
      end

      context 'when group has security_orchestration_policy_configuration' do
        let(:policy) { build(:scan_result_policy, branches: []) }
        let_it_be(:group_configuration, reload: true) do
          create(:security_orchestration_policy_configuration, project: nil, namespace: group)
        end

        before do
          allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
            allow(configuration).to receive(:policy_last_updated_by).and_return(user)
          end

          allow_next_instance_of(Repository) do |repository|
            allow(repository).to receive(:blob_data_at).and_return({ scan_result_policy: [policy] }.to_yaml)
          end
        end

        it 'invokes OrchestrationConfigurationCreateBotWorker', :sidekiq_inline do
          expect(::Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).and_call_original

          expect(created_project.security_policy_bot).to be_present
        end

        context 'when project is created in a sub-group with inherited policy' do
          let(:extra_params) { { namespace_id: sub_group.id } }

          it 'invokes OrchestrationConfigurationCreateBotWorker', :sidekiq_inline do
            expect(::Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).and_call_original

            expect(created_project.security_policy_bot).to be_present
          end
        end
      end

      context 'when group does not have security_orchestration_policy_configuration' do
        let(:extra_params) { { namespace_id: create(:group).id } }

        it 'does not invoke OrchestrationConfigurationCreateBotWorker' do
          expect(::Security::OrchestrationConfigurationCreateBotWorker).not_to receive(:perform_async)

          response
        end
      end
    end
  end
end
