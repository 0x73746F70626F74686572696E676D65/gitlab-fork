# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectPolicy, feature_category: :system_access do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper
  include_context 'ProjectPolicy context'

  using RSpec::Parameterized::TableSyntax

  let(:project) { public_project }

  let_it_be(:auditor) { create(:user, :auditor) }

  subject { described_class.new(current_user, project) }

  before do
    stub_licensed_features(
      license_scanning: true,
      quality_management: true,
      cycle_analytics_for_projects: true
    )
  end

  context 'basic permissions' do
    let(:additional_guest_permissions) { %i[read_limit_alert] }
    let(:additional_reporter_permissions) do
      %i[read_software_license_policy admin_value_stream]
    end

    let(:additional_developer_permissions) do
      %i[
        admin_vulnerability_feedback read_project_audit_events read_project_security_dashboard
        admin_vulnerability_issue_link admin_vulnerability_external_issue_link
        read_security_resource read_vulnerability_scanner admin_vulnerability read_vulnerability
        create_vulnerability_export read_merge_train
      ]
    end

    let(:additional_maintainer_permissions) do
      %i[push_code_to_protected_branches]
    end

    let(:auditor_permissions) do
      %i[
        download_code download_wiki_code read_project read_issue_board read_issue_board_list
        read_project_for_iids read_issue_iid read_merge_request_iid read_wiki
        read_issue read_label read_planning_hierarchy read_issue_link read_milestone
        read_snippet read_project_member read_note read_cycle_analytics
        read_pipeline read_build read_commit_status read_container_image
        read_environment read_deployment read_merge_request read_pages
        award_emoji
        read_project_security_dashboard read_security_resource read_vulnerability_scanner
        read_software_license_policy
        read_merge_train
        read_release
        read_project_audit_events
        read_cluster
        read_terraform_state
        read_project_merge_request_analytics
        read_on_demand_dast_scan
        read_alert_management_alert
      ]
    end

    it_behaves_like 'project policies as anonymous'
    it_behaves_like 'project policies as guest'
    it_behaves_like 'project policies as reporter'
    it_behaves_like 'project policies as developer'
    it_behaves_like 'project policies as maintainer'
    it_behaves_like 'project policies as owner'
    it_behaves_like 'project policies as admin with admin mode'
    it_behaves_like 'project policies as admin without admin mode'

    context 'auditor' do
      let(:current_user) { auditor }
      let(:auditor_permission_exclusions) { [:fork_project, :create_merge_request_in] }

      before do
        stub_licensed_features(security_dashboard: true, license_scanning: true)
      end

      context 'who is not a team member' do
        it do
          is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
          is_expected.to be_disallowed(*maintainer_permissions)
          is_expected.to be_disallowed(*owner_permissions)
          is_expected.to be_disallowed(*(guest_permissions - auditor_permissions))
          is_expected.to be_allowed(*auditor_permission_exclusions)
          is_expected.to be_allowed(*auditor_permissions)
        end

        context 'with private project' do
          let(:project) { private_project }

          let(:auditor_permission_exclusions) { [:fork_project, :create_merge_request_in, :read_project_for_iids] }

          it do
            is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
            is_expected.to be_disallowed(*maintainer_permissions)
            is_expected.to be_disallowed(*owner_permissions)
            is_expected.to be_disallowed(*(guest_permissions - auditor_permissions))
            is_expected.to be_disallowed(*auditor_permission_exclusions)
            is_expected.to be_allowed(*(auditor_permissions - auditor_permission_exclusions))
          end
        end
      end

      context 'who is a team member' do
        before do
          project.add_guest(current_user)
        end

        it do
          is_expected.to be_disallowed(*(developer_permissions - auditor_permissions))
          is_expected.to be_disallowed(*maintainer_permissions)
          is_expected.to be_disallowed(*owner_permissions)
          is_expected.to be_allowed(*(guest_permissions - auditor_permissions))
          is_expected.to be_allowed(*auditor_permissions)
        end
      end

      it_behaves_like 'project private features with read_all_resources ability' do
        let(:user) { current_user }
      end

      context 'with project feature related policies' do
        # Required parameters:
        # - project_feature: Hash defining project feature mapping abilities.
        shared_examples 'project feature visibility' do |project_features|
          # For each project feature, check that an auditor is always allowed read
          # permissions unless the feature is disabled.
          project_features.each do |feature, permissions|
            context "with project feature #{feature}" do
              where(:project_visibility, :access_level, :allowed) do
                :public   | ProjectFeature::ENABLED  | true
                :public   | ProjectFeature::PRIVATE  | true
                :public   | ProjectFeature::DISABLED | false
                :internal | ProjectFeature::ENABLED  | true
                :internal | ProjectFeature::PRIVATE  | true
                :internal | ProjectFeature::DISABLED | false
                :private  | ProjectFeature::ENABLED  | true
                :private  | ProjectFeature::PRIVATE  | true
                :private  | ProjectFeature::DISABLED | false
              end

              with_them do
                let(:project) { send("#{project_visibility}_project") }

                it 'always allows permissions except when feature disabled' do
                  project.project_feature.update!("#{feature}": access_level)

                  if allowed
                    expect_allowed(*permissions)
                  else
                    expect_disallowed(*permissions)
                  end
                end
              end
            end
          end
        end

        include_examples 'project feature visibility', {
          container_registry_access_level: [:read_container_image],
          merge_requests_access_level: [:read_merge_request],
          monitor_access_level: [:read_alert_management_alert]
        }
      end
    end
  end

  context 'iterations' do
    context 'in a personal project' do
      let(:current_user) { owner }

      context 'when feature is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end

      context 'when feature is enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end
    end

    context 'in a group project' do
      let(:project) { public_project_in_group }
      let(:current_user) { maintainer }

      context 'when feature is disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
      end

      context 'when feature is enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }

        context 'when issues are disabled but merge requests are enabled' do
          before do
            project.update!(issues_enabled: false)
          end

          it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        context 'when issues are enabled but merge requests are enabled' do
          before do
            project.update!(merge_requests_enabled: false)
          end

          it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        context 'when both issues and merge requests are disabled' do
          before do
            project.update!(issues_enabled: false, merge_requests_enabled: false)
          end

          it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
        end

        where(:the_user, :allowed, :disallowed) do
          ref(:developer)  | [:read_iteration, :create_iteration, :admin_iteration] | []
          ref(:guest)      | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
          ref(:non_member) | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
          ref(:anonymous)  | [:read_iteration]                                      | [:create_iteration, :admin_iteration]
        end

        with_them do
          let(:current_user) { the_user }

          it { is_expected.to be_allowed(*allowed) }
          it { is_expected.to be_disallowed(*disallowed) }
        end

        context 'when the project is private' do
          let(:project) { private_project }

          context 'when user is not a member' do
            let(:current_user) { non_member }

            it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
          end

          context 'when user is logged out' do
            let(:current_user) { anonymous }

            it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
          end
        end
      end
    end
  end

  context 'issues feature' do
    let(:current_user) { owner }

    context 'when the feature is disabled' do
      before do
        project.update!(issues_enabled: false)
      end

      it 'disables boards permissions' do
        expect_disallowed :admin_issue_board, :create_test_case
      end

      it 'disables issues analytics' do
        expect_disallowed :read_issues_analytics
      end
    end
  end

  context 'merge requests feature' do
    let(:current_user) { owner }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }

    context 'when the feature is disabled' do
      before do
        project.update!(merge_requests_enabled: false)
      end

      it 'disables issues analytics' do
        expect_disallowed :read_project_merge_request_analytics
      end
    end
  end

  context 'admin_mirror' do
    context 'with remote mirror setting enabled' do
      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:admin_mirror) }
      end

      context 'with developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirror setting disabled' do
      before do
        stub_application_setting(mirror_available: false)
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirrors feature disabled' do
      before do
        stub_licensed_features(repository_mirrors: false)
      end

      context 'with admin' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:admin_mirror) }
      end
    end

    context 'with remote mirrors feature enabled' do
      before do
        stub_licensed_features(repository_mirrors: true)
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_mirror) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:admin_mirror) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:admin_mirror) }
      end
    end
  end

  context 'reading a project' do
    context 'with an external authorization service' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows auditors' do
        stub_licensed_features(auditor_user: true)
        auditor = create(:user, :auditor)

        expect(described_class.new(auditor, project)).to be_allowed(:read_project)
      end
    end

    context 'when SAML SSO is enabled for resource' do
      let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: false) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
      let(:root_group) { saml_provider.group }
      let(:project) { create(:project, group: root_group) }
      let(:member_with_identity) { identity.user }
      let(:member_without_identity) { create(:user) }
      let(:non_member) { create(:user) }
      let(:not_signed_in_user) { nil }

      before do
        stub_licensed_features(group_saml: true)
        root_group.add_developer(member_with_identity)
        root_group.add_developer(member_without_identity)
      end

      subject { described_class.new(current_user, resource) }

      shared_examples 'does not allow read project' do
        it 'does not allow read project' do
          is_expected.not_to allow_action(:read_project)
        end
      end

      shared_examples 'allows to read project' do
        it 'allows read project' do
          is_expected.to allow_action(:read_project)
        end
      end

      shared_examples 'does not allow to read project due to its visibility level' do
        it 'does not allow to read project due to its visibility level', :aggregate_failures do
          expect(resource.root_ancestor.saml_provider.enforced_sso?).to eq(false)

          is_expected.not_to allow_action(:read_project)
        end
      end

      # See https://docs.gitlab.com/ee/user/group/saml_sso/#sso-enforcement
      where(:resource, :resource_visibility_level, :enforced_sso?, :user, :user_is_resource_owner?, :user_with_saml_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
        # Project/Group visibility: Private; Enforce SSO setting: Off

        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read project'

        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read project due to its visibility level'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read project due to its visibility level'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read project'
        ref(:project)    | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read project due to its visibility level'

        # Project/Group visibility: Private; Enforce SSO setting: On

        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read project'
        ref(:project)    | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read project'

        # Project/Group visibility: Public; Enforce SSO setting: Off

        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read project'

        ref(:project)    | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read project'

        # Project/Group visibility: Public; Enforce SSO setting: On

        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read project'

        ref(:project)    | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
        ref(:project)    | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read project'
      end

      with_them do
        context "when 'Enforce SSO-only authentication for web activity for this group' option is #{params[:enforced_sso?] ? 'enabled' : 'not enabled'}" do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          before do
            saml_provider.update!(enforced_sso: enforced_sso?)
          end

          context "when resource is #{params[:resource_visibility_level]}" do
            before do
              resource.update!(visibility_level: Gitlab::VisibilityLevel.string_options[resource_visibility_level])
            end

            context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
              before do
                if user_is_resource_owner?
                  resource.root_ancestor.member(user).update_column(:access_level, Gitlab::Access::OWNER)
                end

                Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session if user_with_saml_session?

                user.update!(admin: true) if user_is_admin?
                user.update!(auditor: true) if user_is_auditor?
              end

              let(:current_user) { user }

              include_examples params[:shared_examples]
            end
          end
        end
      end
    end

    context 'with ip restriction' do
      let(:current_user) { create(:admin) }
      let(:group) { create(:group, :public) }
      let(:project) { create(:project, group: group) }

      before do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
        stub_licensed_features(group_ip_restriction: true)
        group.add_maintainer(current_user)
      end

      context 'group without restriction' do
        it { is_expected.to be_allowed(:read_project) }
        it { is_expected.to be_allowed(:read_issue) }
        it { is_expected.to be_allowed(:read_merge_request) }
        it { is_expected.to be_allowed(:read_milestone) }
        it { is_expected.to be_allowed(:read_container_image) }
        it { is_expected.to be_allowed(:read_package) }
        it { is_expected.to be_allowed(:create_package) }
        it { is_expected.to be_allowed(:destroy_package) }
        it { is_expected.to be_allowed(:admin_package) }
      end

      context 'group with restriction' do
        before do
          create(:ip_restriction, group: group, range: range)
        end

        context 'address is within the range' do
          let(:range) { '192.168.0.0/24' }

          it { is_expected.to be_allowed(:read_project) }
          it { is_expected.to be_allowed(:read_issue) }
          it { is_expected.to be_allowed(:read_merge_request) }
          it { is_expected.to be_allowed(:read_milestone) }
          it { is_expected.to be_allowed(:read_container_image) }
          it { is_expected.to be_allowed(:create_container_image) }
          it { is_expected.to be_allowed(:read_package) }
          it { is_expected.to be_allowed(:create_package) }
          it { is_expected.to be_allowed(:destroy_package) }
          it { is_expected.to be_allowed(:admin_package) }
        end

        context 'address is outside the range' do
          let(:range) { '10.0.0.0/8' }

          it { is_expected.to be_disallowed(:read_project) }
          it { is_expected.to be_disallowed(:read_issue) }
          it { is_expected.to be_disallowed(:read_merge_request) }
          it { is_expected.to be_disallowed(:read_milestone) }
          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
          it { is_expected.to be_disallowed(:read_package) }
          it { is_expected.to be_disallowed(:create_package) }
          it { is_expected.to be_disallowed(:destroy_package) }
          it { is_expected.to be_disallowed(:admin_package) }

          context 'with admin enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_project) }
            it { is_expected.to be_allowed(:read_issue) }
            it { is_expected.to be_allowed(:read_merge_request) }
            it { is_expected.to be_allowed(:read_milestone) }
            it { is_expected.to be_allowed(:read_container_image) }
            it { is_expected.to be_allowed(:create_container_image) }
            it { is_expected.to be_allowed(:read_package) }
            it { is_expected.to be_allowed(:create_package) }
            it { is_expected.to be_allowed(:destroy_package) }
            it { is_expected.to be_allowed(:admin_package) }
          end

          context 'with admin disabled' do
            it { is_expected.to be_disallowed(:read_project) }
            it { is_expected.to be_disallowed(:read_issue) }
            it { is_expected.to be_disallowed(:read_merge_request) }
            it { is_expected.to be_disallowed(:read_milestone) }
            it { is_expected.to be_disallowed(:read_container_image) }
            it { is_expected.to be_disallowed(:create_container_image) }
            it { is_expected.to be_disallowed(:read_package) }
            it { is_expected.to be_disallowed(:create_package) }
            it { is_expected.to be_disallowed(:destroy_package) }
            it { is_expected.to be_disallowed(:admin_package) }
          end

          context 'with auditor' do
            let(:current_user) { create(:user, :auditor) }

            it { is_expected.to be_allowed(:read_project) }
            it { is_expected.to be_allowed(:read_issue) }
            it { is_expected.to be_allowed(:read_merge_request) }
            it { is_expected.to be_allowed(:read_milestone) }
            it { is_expected.to be_allowed(:read_container_image) }
            it { is_expected.to be_allowed(:create_container_image) }
            it { is_expected.to be_allowed(:read_package) }
            it { is_expected.to be_allowed(:create_package) }
            it { is_expected.to be_allowed(:destroy_package) }
            it { is_expected.to be_allowed(:admin_package) }
          end
        end
      end

      context 'without group' do
        let(:project) { create(:project, :repository, namespace: current_user.namespace) }

        it { is_expected.to be_allowed(:read_project) }
      end
    end
  end

  describe 'access_security_and_compliance' do
    shared_examples 'correct access to security and compliance' do
      before do
        project.project_feature.update!(security_and_compliance_access_level: access_level)
      end

      context 'when "Security and Compliance" is disabled' do
        let(:access_level) { Featurable::DISABLED }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
        it { is_expected.to be_disallowed(:admin_vulnerability) }
        it { is_expected.to be_disallowed(:read_vulnerability) }
      end

      context 'when "Security and Compliance" is enabled' do
        let(:access_level) { Featurable::PRIVATE }

        it { is_expected.to be_allowed(:access_security_and_compliance) }
      end
    end

    context 'when the user is developer' do
      let(:current_user) { developer }

      it_behaves_like 'correct access to security and compliance'
    end

    context 'when the user has a custom role that enables read_vulnerability' do
      let(:current_user) { guest }
      let_it_be(:project) { create(:project, :in_group) }

      before do
        stub_licensed_features(custom_roles: true)
        project_member = create(:project_member, :guest, user: current_user, source: project)
        create(:member_role, :guest, read_vulnerability: true, members: [project_member], namespace: project.group)
      end

      it_behaves_like 'correct access to security and compliance'
    end

    context 'when the user is auditor' do
      let(:current_user) { create(:user, :auditor) }

      it_behaves_like 'correct access to security and compliance'
    end
  end

  describe 'vulnerability feedback permissions' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_vulnerability_feedback) }
      it { is_expected.to be_disallowed(:create_vulnerability_feedback) }
      it { is_expected.to be_disallowed(:update_vulnerability_feedback) }
      it { is_expected.to be_disallowed(:destroy_vulnerability_feedback) }
    end

    where(permission: %i[
      read_vulnerability_feedback
            create_vulnerability_feedback
            update_vulnerability_feedback
            destroy_vulnerability_feedback
    ])

    with_them do
      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(permission) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(permission) }
        end
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(permission) }
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(permission) }
      end

      context 'with reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(permission) }
      end

      context 'with guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(permission) }
      end

      context 'with non member' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(permission) }
      end

      context 'with anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(permission) }
      end
    end
  end

  shared_context 'when security dashboard feature is not available' do
    before do
      stub_licensed_features(security_dashboard: false)
    end
  end

  describe 'read_project_security_dashboard' do
    context 'with developer' do
      let(:current_user) { developer }

      include_context 'when security dashboard feature is not available'

      it { is_expected.to be_disallowed(:read_project_security_dashboard) }
    end
  end

  describe 'vulnerability permissions' do
    describe 'dismiss_vulnerability' do
      context 'with developer' do
        let(:current_user) { developer }

        include_context 'when security dashboard feature is not available'
        it { is_expected.to be_disallowed(:admin_vulnerability) }
        it { is_expected.to be_disallowed(:read_vulnerability) }
        it { is_expected.to be_disallowed(:create_vulnerability_export) }
      end
    end
  end

  describe 'permissions for security bot' do
    let_it_be(:current_user) { create(:user, :security_bot) }

    let(:project) { private_project }

    let(:permissions) do
      %i[
        reporter_access
        push_code
        create_merge_request_from
        create_merge_request_in
        create_vulnerability_feedback
        read_project
        admin_merge_request
      ]
    end

    context 'when project does not have a security_setting' do
      before do
        project.security_setting.delete
        project.reload
      end

      it { is_expected.to be_allowed(*permissions) }

      context 'with user other than security bot' do
        let_it_be(:current_user) { create(:user) }

        it { is_expected.to be_disallowed(*permissions) }
      end
    end
  end

  describe 'security orchestration policies' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'with developer or maintainer role' do
      where(role: %w[maintainer developer])

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:read_security_orchestration_policies) }
        it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
      end
    end

    context 'with owner role' do
      where(role: %w[owner])

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:read_security_orchestration_policies) }
        it { is_expected.to be_allowed(:update_security_orchestration_policy_project) }
        it { is_expected.to be_allowed(:modify_security_policy) }

        context 'when security_orchestration_policy_configuration is present' do
          let_it_be(:security_policy_management_project) { create(:project) }

          before do
            create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project)
          end

          it { is_expected.to be_disallowed(:modify_security_policy) }
        end
      end
    end

    context 'with auditor role' do
      where(role: %w[auditor])

      before do
        project.project_feature.update!(security_orchestration_policies: feature_status)
      end

      context 'with policy feature enabled' do
        let(:feature_status) { ProjectFeature::ENABLED }

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:read_security_orchestration_policies) }
          it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
        end
      end

      context 'with policy feature disabled' do
        let(:feature_status) { ProjectFeature::DISABLED }

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:read_security_orchestration_policies) }
          it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
        end
      end
    end

    context 'when security_orchestration_policy_configuration is present' do
      let_it_be(:security_policy_management_project) { create(:project) }
      let(:current_user) { developer }

      before do
        create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project)
      end

      context 'when current_user is developer of security_policy_management_project' do
        before do
          security_policy_management_project.add_developer(developer)
        end

        it { is_expected.to be_allowed(:modify_security_policy) }
      end

      context 'when current_user is not developer of security_policy_management_project' do
        it { is_expected.to be_disallowed(:modify_security_policy) }
      end
    end
  end

  describe 'coverage_fuzzing' do
    context 'when coverage_fuzzing feature is available' do
      before do
        stub_licensed_features(coverage_fuzzing: true)
      end

      context 'with developer or higher role' do
        where(role: %w[owner maintainer developer])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:read_coverage_fuzzing) }
        end
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:read_coverage_fuzzing) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
        end
      end

      context 'with less than developer role' do
        where(role: %w[reporter guest])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
        end
      end

      context 'with non member' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
      end

      context 'with anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
      end
    end

    context 'when coverage fuzzing feature is not available' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(coverage_fuzzing: true)
      end

      it { is_expected.to be_disallowed(:read_coverage_fuzzing) }
    end
  end

  describe 'remove_project when default_project_deletion_protection is set to true' do
    before do
      allow(Gitlab::CurrentSettings.current_application_settings)
        .to receive(:default_project_deletion_protection) { true }
    end

    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:remove_project) }
      end

      context 'when admin mode disabled' do
        it { is_expected.to be_disallowed(:remove_project) }
      end

      context 'who owns the project' do
        let(:project) { create(:project, :public, namespace: admin.namespace) }

        it { is_expected.to be_disallowed(:remove_project) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:remove_project) }
    end
  end

  describe 'admin_feature_flags_issue_links' do
    before do
      stub_licensed_features(feature_flags_related_issues: true)
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:admin_feature_flags_issue_links) }

      context 'when repository is disabled' do
        before do
          project.project_feature.update!(
            merge_requests_access_level: ProjectFeature::DISABLED,
            builds_access_level: ProjectFeature::DISABLED,
            repository_access_level: ProjectFeature::DISABLED
          )
        end

        it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
      end
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:admin_feature_flags_issue_links) }

      context 'when feature is unlicensed' do
        before do
          stub_licensed_features(feature_flags_related_issues: false)
        end

        it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:admin_feature_flags_issue_links) }
    end
  end

  describe 'admin_software_license_policy' do
    context 'without license scanning feature available' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      let(:current_user) { admin }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end

    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:admin_software_license_policy) }
      end

      context 'when admin mode disabled' do
        it { is_expected.to be_disallowed(:admin_software_license_policy) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:admin_software_license_policy) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:admin_software_license_policy) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end

    context 'with non member' do
      let(:current_user) { non_member }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end

    context 'with anonymous' do
      let(:current_user) { anonymous }

      it { is_expected.to be_disallowed(:admin_software_license_policy) }
    end
  end

  describe 'read_software_license_policy' do
    context 'without license scanning feature available' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      let(:current_user) { admin }

      it { is_expected.to be_disallowed(:read_software_license_policy) }
    end
  end

  describe 'read_dependency' do
    context 'when dependency scanning feature available' do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      context 'with public project' do
        let(:current_user) { create(:user) }

        context 'with public access to repository' do
          let(:project) { public_project }

          it { is_expected.to be_allowed(:read_dependency) }
        end

        context 'with limited access to repository' do
          let(:project) { create(:project, :public, :repository_private) }

          it { is_expected.not_to be_allowed(:read_dependency) }
        end
      end

      context 'with private project' do
        let(:project) { private_project }

        context 'with admin' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_dependency) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:read_dependency) }
          end
        end

        context 'with owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:read_dependency) }
        end

        context 'with maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_allowed(:read_dependency) }
        end

        context 'with developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(:read_dependency) }
        end

        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:read_dependency) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_dependency) }
        end

        context 'with non member' do
          let(:current_user) { non_member }

          it { is_expected.to be_disallowed(:read_dependency) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:read_dependency) }
        end
      end
    end

    context 'when dependency list feature not available' do
      let(:current_user) { admin }

      it { is_expected.not_to be_allowed(:read_dependency) }
    end
  end

  describe 'read_licenses' do
    context 'when license management feature available' do
      context 'with public project' do
        let(:current_user) { non_member }

        context 'with public access to repository' do
          it { is_expected.to be_allowed(:read_licenses) }
        end
      end

      context 'with private project' do
        let(:project) { private_project }

        where(role: %w[owner maintainer developer reporter])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:read_licenses) }
        end

        context 'with admin' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:read_licenses) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:read_licenses) }
          end
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_licenses) }
        end

        context 'with non member' do
          let(:current_user) { non_member }

          it { is_expected.to be_disallowed(:read_licenses) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:read_licenses) }
        end
      end
    end

    context 'when license management feature in not available' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      let(:current_user) { admin }

      it { is_expected.to be_disallowed(:read_licenses) }
    end
  end

  describe 'publish_status_page' do
    let(:feature) { :status_page }
    let(:policy) { :publish_status_page }

    context 'when feature is available' do
      where(:role, :admin_mode, :allowed) do
        :anonymous  | nil   | false
        :guest      | nil   | false
        :reporter   | nil   | false
        :developer  | nil   | true
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
      end

      with_them do
        let(:current_user) { public_send(role) if role }

        before do
          stub_licensed_features(feature => true)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'when feature is not available' do
          before do
            stub_licensed_features(feature => false)
          end

          it { is_expected.to be_disallowed(policy) }
        end
      end
    end
  end

  describe 'add_project_to_instance_security_dashboard' do
    let(:policy) { :add_project_to_instance_security_dashboard }

    context 'when user is auditor' do
      let(:current_user) { create(:user, :auditor) }

      it { is_expected.to be_allowed(policy) }
    end

    context 'when user is not auditor' do
      context 'with developer access' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(policy) }
      end

      context 'without developer access' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_disallowed(policy) }
      end
    end
  end

  context 'visual review bot' do
    let(:current_user) { Users::Internal.visual_review_bot }

    it { expect_disallowed(:create_note) }
    it { expect_disallowed(:read_note) }
    it { expect_disallowed(:resolve_note) }
  end

  context 'when push_rules is not enabled by the current license' do
    before do
      stub_licensed_features(push_rules: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:change_push_rules) }
  end

  context 'when push_rules is enabled by the current license' do
    before do
      stub_licensed_features(push_rules: true)
    end

    let(:current_user) { maintainer }

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_push_rules) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_push_rules) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:change_push_rules) }
    end
  end

  context 'commit_committer_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_commit_committer_check) }
    it { is_expected.not_to be_allowed(:read_commit_committer_check) }
  end

  context 'commit_committer_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_commit_committer_check) }
      it { is_expected.to be_allowed(:read_commit_committer_check) }
    end

    context 'the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_commit_committer_check) }
      it { is_expected.to be_allowed(:read_commit_committer_check) }
    end

    context 'the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_commit_committer_check) }
      it { is_expected.not_to be_allowed(:read_commit_committer_check) }
    end
  end

  context 'when commit_committer_name_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_commit_committer_name_check) }
    it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
  end

  context 'when commit_committer_name_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_commit_committer_name_check) }
      it { is_expected.to be_allowed(:change_commit_committer_name_check) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_commit_committer_name_check) }
      it { is_expected.to be_allowed(:change_commit_committer_name_check) }
    end

    context 'the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:read_commit_committer_name_check) }
      it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
    end
  end

  context 'reject_unsigned_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
    it { is_expected.not_to be_allowed(:read_reject_unsigned_commits) }
  end

  context 'reject_unsigned_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.not_to be_allowed(:read_reject_unsigned_commits) }
    end
  end

  context 'when reject_non_dco_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_reject_non_dco_commits) }
    it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
  end

  context 'when reject_non_dco_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_reject_non_dco_commits) }
      it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_reject_non_dco_commits) }
      it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:read_reject_non_dco_commits) }
      it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
    end
  end

  context 'when dora4 analytics is available' do
    before do
      stub_licensed_features(dora4_analytics: true)
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_dora4_analytics) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_dora4_analytics) }
    end
  end

  context 'when dora4 analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(dora4_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_dora4_analytics) }
  end

  describe ':read_ai_analytics' do
    let(:current_user) { reporter }

    it { is_expected.to be_allowed(:read_ai_analytics) }

    context 'when user is a guest' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:read_ai_analytics) }
    end
  end

  describe ':read_code_review_analytics' do
    let(:project) { private_project }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :reporter   | nil   | true
      :developer  | nil   | true
      :maintainer | nil   | true
      :owner      | nil   | true
      :admin      | false | false
      :admin      | true  | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(code_review_analytics: true)
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(:read_code_review_analytics) : be_disallowed(:read_code_review_analytics)) }
    end

    context 'with code review analytics is not available in license' do
      let(:current_user) { owner }

      before do
        stub_licensed_features(code_review_analytics: false)
      end

      it { is_expected.to be_disallowed(:read_code_review_analytics) }
    end
  end

  shared_examples 'merge request approval settings' do |admin_override_allowed = false|
    let(:project) { private_project }

    context 'with merge request approvers rules available in license' do
      where(:role, :setting, :admin_mode, :allowed) do
        :guest      | true  | nil    | false
        :reporter   | true  | nil    | false
        :developer  | true  | nil    | false
        :maintainer | false | nil    | true
        :maintainer | true  | nil    | false
        :owner      | false | nil    | true
        :owner      | true  | nil    | false
        :admin      | false | false  | false
        :admin      | false | true   | true
        :admin      | true  | false  | false
        :admin      | true  | true   | admin_override_allowed
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(admin_merge_request_approvers_rules: true)
          stub_application_setting(app_setting => setting)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'with merge request approvers rules not available in license' do
      where(:role, :setting, :admin_mode, :allowed) do
        :guest      | true  | nil    | false
        :reporter   | true  | nil    | false
        :developer  | true  | nil    | false
        :maintainer | false | nil    | true
        :maintainer | true  | nil    | true
        :owner      | false | nil    | true
        :owner      | true  | nil    | true
        :admin      | false | false  | false
        :admin      | false | true   | true
        :admin      | true  | false  | false
        :admin      | true  | true   | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(admin_merge_request_approvers_rules: false)
          stub_application_setting(app_setting => setting)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe ':admin_merge_request_approval_settings' do
    let(:project) { private_project }

    where(:role, :licensed, :allowed) do
      :guest      | true  | false
      :reporter   | true  | false
      :developer  | true  | false
      :maintainer | false | false
      :maintainer | true  | true
      :owner      | false | false
      :owner      | true  | true
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(merge_request_approvers: licensed)
        enable_admin_mode!(current_user) if role == :admin
      end

      it { is_expected.to(allowed ? be_allowed(:admin_merge_request_approval_settings) : be_disallowed(:admin_merge_request_approval_settings)) }
    end
  end

  describe ':modify_approvers_rules' do
    it_behaves_like 'merge request approval settings', true do
      let(:app_setting) { :disable_overriding_approvers_per_merge_request }
      let(:policy) { :modify_approvers_rules }
    end
  end

  describe ':modify_merge_request_author_setting' do
    it_behaves_like 'merge request approval settings' do
      let(:app_setting) { :prevent_merge_requests_author_approval }
      let(:policy) { :modify_merge_request_author_setting }
    end
  end

  describe ':modify_merge_request_committer_setting' do
    it_behaves_like 'merge request approval settings' do
      let(:app_setting) { :prevent_merge_requests_committers_approval }
      let(:policy) { :modify_merge_request_committer_setting }
    end
  end

  it_behaves_like 'resource with requirement permissions' do
    let(:resource) { project }
  end

  describe 'Quality Management test case' do
    let(:policy) { :create_test_case }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :reporter   | nil   | true
      :developer  | nil   | true
      :maintainer | nil   | true
      :owner      | nil   | true
      :admin      | false | false
      :admin      | true  | true
    end

    before do
      stub_licensed_features(quality_management: true)
      enable_admin_mode!(current_user) if admin_mode
    end

    with_them do
      let(:current_user) { public_send(role) }

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

      context 'with unavailable license' do
        before do
          stub_licensed_features(quality_management: false)
        end

        it { is_expected.to(be_disallowed(policy)) }
      end
    end
  end

  shared_examples_for 'prevents CI cancellation ability' do
    context 'when feature is enabled' do
      where(:restricted_role, :actual_role, :allowed) do
        :developer  | :guest      | false
        :developer  | :reporter   | false
        :developer  | :developer  | true
        :developer  | :maintainer | true
        :developer  | :owner      | true
        :maintainer | :guest      | false
        :maintainer | :reporter   | false
        :maintainer | :developer  | false
        :maintainer | :maintainer | true
        :maintainer | :owner      | true
        :no_one     | :guest      | false
        :no_one     | :reporter   | false
        :no_one     | :developer  | false
        :no_one     | :maintainer | false
        :no_one     | :owner      | false
      end

      with_them do
        let(:current_user) { public_send(actual_role) }

        before do
          stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
          project.update!(restrict_pipeline_cancellation_role: restricted_role)
        end

        it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
      end
    end
  end

  describe 'prevents cancel_pipeline when CI cancllation restricted' do
    let(:ability) { :cancel_pipeline }

    it_behaves_like 'prevents CI cancellation ability'
  end

  describe 'prevents cancel_build when CI cancllation restricted' do
    let(:ability) { :cancel_build }

    it_behaves_like 'prevents CI cancellation ability'
  end

  describe ':compliance_framework_available' do
    let(:policy) { :admin_compliance_framework }

    where(:role, :feature_enabled, :admin_mode, :allowed) do
      :guest      | false | nil   | false
      :guest      | true  | nil   | false
      :reporter   | false | nil   | false
      :reporter   | true  | nil   | false
      :developer  | false | nil   | false
      :maintainer | false | nil   | false
      :maintainer | true  | nil   | false
      :owner      | false | nil   | false
      :owner      | true  | nil   | true
      :admin      | false | false | false
      :admin      | false | true  | false
      :admin      | true  | false | false
      :admin      | true  | true  | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(compliance_framework: feature_enabled)
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'Incident Management on-call schedules' do
    let(:current_user) { public_send(role) }
    let(:admin_mode) { false }

    before do
      enable_admin_mode!(current_user) if admin_mode
      stub_licensed_features(oncall_schedules: true)
    end

    context ':read_incident_management_oncall_schedule' do
      let(:policy) { :read_incident_management_oncall_schedule }

      where(:role, :admin_mode, :allowed) do
        :guest      | nil   | false
        :reporter   | nil   | true
        :developer  | nil   | true
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
        :auditor    | false | true
      end

      with_them do
        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with unavailable license' do
          before do
            stub_licensed_features(oncall_schedules: false)
          end

          it { is_expected.to(be_disallowed(policy)) }
        end
      end

      it_behaves_like 'monitor feature visibility', allow_lowest_role: :reporter
    end

    context ':admin_incident_management_oncall_schedule' do
      let(:policy) { :admin_incident_management_oncall_schedule }

      where(:role, :admin_mode, :allowed) do
        :guest      | nil   | false
        :reporter   | nil   | false
        :developer  | nil   | false
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
        :auditor    | false | false
      end

      with_them do
        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with unavailable license' do
          before do
            stub_licensed_features(oncall_schedules: false)
          end

          it { is_expected.to(be_disallowed(policy)) }
        end
      end

      it_behaves_like 'monitor feature visibility', allow_lowest_role: :maintainer
    end
  end

  describe 'Escalation Policies' do
    let(:current_user) { public_send(role) }
    let(:admin_mode) { false }

    before do
      enable_admin_mode!(current_user) if admin_mode
      allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(true)
    end

    context ':read_incident_management_escalation_policy' do
      let(:policy) { :read_incident_management_escalation_policy }

      where(:role, :admin_mode, :allowed) do
        :guest      | nil   | false
        :reporter   | nil   | true
        :developer  | nil   | true
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
        :auditor    | false | true
      end

      with_them do
        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with unavailable escalation policies' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(false)
          end

          it { is_expected.to(be_disallowed(policy)) }
        end
      end

      it_behaves_like 'monitor feature visibility', allow_lowest_role: :reporter
    end

    context ':admin_incident_management_escalation_policy' do
      let(:policy) { :admin_incident_management_escalation_policy }

      where(:role, :admin_mode, :allowed) do
        :guest      | nil   | false
        :reporter   | nil   | false
        :developer  | nil   | false
        :maintainer | nil   | true
        :owner      | nil   | true
        :admin      | false | false
        :admin      | true  | true
        :auditor    | false | false
      end

      with_them do
        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }

        context 'with unavailable escalation policies' do
          before do
            allow(::Gitlab::IncidentManagement).to receive(:escalation_policies_available?).with(project).and_return(false)
          end

          it { is_expected.to(be_disallowed(policy)) }
        end
      end

      it_behaves_like 'monitor feature visibility', allow_lowest_role: :maintainer
    end
  end

  context 'when project is read only on the namespace' do
    let(:project) { public_project_in_group }
    let(:current_user) { maintainer }
    let(:abilities) do
      described_class.readonly_features.flat_map { |feature| described_class.create_update_admin(feature) } +
        described_class.readonly_abilities
    end

    before do
      allow(project.root_namespace).to receive(:read_only?).and_return(read_only)
      allow(project).to receive(:design_management_enabled?).and_return(true)
      stub_licensed_features(security_dashboard: true, license_scanning: true, quality_management: true)
    end

    context 'when the group is read only' do
      let(:read_only) { true }

      it { is_expected.to(be_disallowed(*abilities)) }
    end

    context 'when the group is not read only' do
      let(:read_only) { false }

      # These are abilities that are not explicitly allowed by policies because most of them are not
      # real abilities.  They are prevented due to the use of create_update_admin helper method.
      let(:abilities_not_currently_enabled) do
        %i[create_merge_request create_issue_board_list create_issue_board update_issue_board
           update_issue_board_list create_label update_label create_milestone
           update_milestone update_wiki update_design admin_design update_note
           update_pipeline_schedule admin_pipeline_schedule create_trigger update_trigger
           admin_trigger create_pages admin_release request_access create_board update_board
           create_issue_link update_issue_link create_approvers admin_approvers
           admin_vulnerability_feedback create_feature_flags_client
           update_feature_flags_client update_iteration update_vulnerability create_vulnerability]
      end

      it { is_expected.to(be_allowed(*(abilities - abilities_not_currently_enabled))) }
    end
  end

  context 'project access tokens' do
    context 'GitLab.com Core resource access tokens', :saas do
      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'with admin access' do
        let(:current_user) { owner }

        before do
          project.add_owner(owner)
        end

        context 'when project belongs to a group' do
          let_it_be(:group) { create(:group) }
          let_it_be(:project) { create(:project, group: group) }

          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          it { is_expected.to be_allowed(:read_resource_access_tokens) }
          it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
        end

        context 'when project belongs to personal namespace' do
          it { is_expected.to be_allowed(:create_resource_access_tokens) }
          it { is_expected.to be_allowed(:read_resource_access_tokens) }
          it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
        end
      end

      context 'with non admin access' do
        let(:current_user) { developer }

        before do
          project.add_developer(developer)
        end

        context 'when project belongs to a group' do
          let_it_be(:group) { create(:group) }
          let_it_be(:project) { create(:project, group: group) }

          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
          it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
        end

        context 'when project belongs to personal namespace' do
          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
          it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
        end
      end
    end

    context 'on GitLab.com paid', :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :bronze_plan) }
      let_it_be(:project) { create(:project, group: group) }

      context 'with maintainer access' do
        let(:current_user) { maintainer }

        before do
          project.add_maintainer(maintainer)
        end

        it_behaves_like 'GitLab.com Paid plan resource access tokens'

        context 'create resource access tokens' do
          it { is_expected.to be_allowed(:create_resource_access_tokens) }

          context 'with a personal namespace project' do
            let(:namespace) { create(:namespace_with_plan, plan: :bronze_plan) }
            let(:project) { create(:project, namespace: namespace) }

            it { is_expected.to be_allowed(:create_resource_access_tokens) }
          end

          context 'when resource access token creation is not allowed' do
            before do
              group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
            end

            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          end

          context 'when parent group has resource access token creation disabled' do
            let(:resource_access_token_creation_allowed) { false }
            let(:ns_for_parent) { create(:namespace_settings, resource_access_token_creation_allowed: resource_access_token_creation_allowed) }
            let(:parent) { create(:group_with_plan, plan: :bronze_plan, namespace_settings: ns_for_parent) }
            let(:group) { create(:group, parent: parent) }
            let(:project) { create(:project, group: group) }

            context 'cannot create resource access tokens' do
              it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            end
          end
        end

        context 'read resource access tokens' do
          it { is_expected.to be_allowed(:read_resource_access_tokens) }
        end

        context 'destroy resource access tokens' do
          it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
        end
      end

      context 'with developer access' do
        let(:current_user) { developer }

        before do
          project.add_developer(developer)
        end

        context 'create resource access tokens' do
          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
        end

        context 'read resource access tokens' do
          it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
        end

        context 'destroy resource access tokens' do
          it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
        end
      end

      context 'with auditor access' do
        let(:current_user) { auditor }

        context 'read resource access tokens' do
          it { is_expected.to be_allowed(:read_resource_access_tokens) }
        end

        context 'cannot create resource access tokens' do
          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
        end

        context 'cannot destroy resource access tokens' do
          it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
        end
      end
    end
  end

  describe 'read_analytics' do
    context 'with various analytics features' do
      let_it_be(:project_with_analytics_disabled) { create(:project, :analytics_disabled) }
      let_it_be(:project_with_analytics_private) { create(:project, :analytics_private) }
      let_it_be(:project_with_analytics_enabled) { create(:project, :analytics_enabled) }

      let(:all_read_analytics_permissions) do
        %i[
          read_project_merge_request_analytics
        read_code_review_analytics
        read_cycle_analytics
        read_issue_analytics
        ]
      end

      before do
        stub_licensed_features(issues_analytics: true, code_review_analytics: true, project_merge_request_analytics: true, cycle_analytics_for_projects: true)

        project_with_analytics_disabled.add_developer(developer)
        project_with_analytics_private.add_developer(developer)
        project_with_analytics_enabled.add_developer(developer)
      end

      context 'when analytics is disabled for the project' do
        let(:project) { project_with_analytics_disabled }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
        end

        context 'for admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
        end

        context 'for auditor' do
          let(:current_user) { auditor }

          it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
        end
      end

      context 'when analytics is private for the project' do
        let(:project) { project_with_analytics_private }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(*all_read_analytics_permissions) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end

        context 'for admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end

        context 'for auditor' do
          let(:current_user) { auditor }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end
      end

      context 'when analytics is enabled for the project' do
        let(:project) { project_with_analytics_enabled }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_project_merge_request_analytics) }
          it { is_expected.to be_disallowed(:read_code_review_analytics) }
          it { is_expected.to be_disallowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_issue_analytics) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end

        context 'for admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end

        context 'for auditor' do
          let(:current_user) { auditor }

          it { is_expected.to be_allowed(*all_read_analytics_permissions) }
        end
      end
    end
  end

  describe ':build_read_project' do
    let(:policy) { :build_read_project }

    where(:role, :project_visibility, :allowed) do
      :guest      | 'public'   | true
      :reporter   | 'public'   | true
      :developer  | 'public'   | true
      :maintainer | 'public'   | true
      :owner      | 'public'   | true
      :admin      | 'public'   | true
      :guest      | 'internal' | true
      :reporter   | 'internal' | true
      :developer  | 'internal' | true
      :maintainer | 'internal' | true
      :owner      | 'internal' | true
      :admin      | 'internal' | true
      :guest      | 'private'  | false
      :reporter   | 'private'  | true
      :developer  | 'private'  | true
      :maintainer | 'private'  | true
      :owner      | 'private'  | true
      :admin      | 'private'  | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        project.update_column(:visibility_level, Gitlab::VisibilityLevel.level_value(project_visibility))
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'pending member permissions' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group, :public) }

    context 'with a pending membership in a private project' do
      let_it_be(:project) { create(:project, :private, public_builds: false) }

      where(:role) do
        Gitlab::Access.sym_options.keys.map(&:to_sym)
      end

      with_them do
        it 'a pending member has permissions to the project as if the user is not a member' do
          create(:project_member, :awaiting, role, source: project, user: current_user)

          expect_private_project_permissions_as_if_non_member
        end
      end
    end

    context 'with a group invited to a project' do
      let_it_be(:project) { create(:project, :private, public_builds: false) }

      before_all do
        create(:project_group_link, project: project, group: group)
      end

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it 'a pending member in the group has permissions to the project as if the user is not a member' do
          create(:group_member, :awaiting, role, source: group, user: current_user)

          expect_private_project_permissions_as_if_non_member
        end
      end
    end

    context 'with a group invited to another group' do
      let_it_be(:other_group) { create(:group, :public) }
      let_it_be(:project) { create(:project, :private, public_builds: false, namespace: other_group) }

      before_all do
        create(:group_group_link, shared_with_group: group, shared_group: other_group)
      end

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it "a pending member in the group has permissions to the other group's project as if the user is not a member" do
          create(:group_member, :awaiting, role, source: group, user: current_user)

          expect_private_project_permissions_as_if_non_member
        end
      end
    end

    context 'with a subgroup' do
      let_it_be(:subgroup) { create(:group, :private, parent: group) }
      let_it_be(:project) { create(:project, :private, public_builds: false, namespace: subgroup) }

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it 'a pending member in the group has permissions to the subgroup project as if the user is not a member' do
          create(:group_member, :awaiting, role, source: group, user: current_user)

          expect_private_project_permissions_as_if_non_member
        end
      end
    end

    def expect_private_project_permissions_as_if_non_member
      expect_disallowed(*guest_permissions)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*team_member_reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end

    describe ':read_approvers' do
      let(:policy) { :read_approvers }

      where(:role, :allowed) do
        :guest      | false
        :reporter   | false
        :developer  | false
        :maintainer | true
        :auditor    | true
        :owner      | true
        :admin      | true
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if role == :admin
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  context 'importing members from another project' do
    let(:current_user) { owner }

    context 'for a personal project' do
      it { is_expected.to be_allowed(:import_project_members_from_another_project) }
    end

    context 'for a project in a group' do
      let(:project) { create(:project, group: create(:group)) }

      context 'when the project has locked their membership' do
        context 'via the parent group' do
          before do
            project.group.update!(membership_lock: true)
          end

          it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
        end

        context 'via LDAP' do
          before do
            stub_application_setting(lock_memberships_to_ldap: true)
          end

          it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
        end

        context 'via SAML' do
          before do
            stub_application_setting(lock_memberships_to_saml: true)
          end

          it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
        end
      end
    end
  end

  describe 'inviting a group' do
    let_it_be_with_reload(:current_user) { developer }
    let_it_be_with_reload(:project) { public_project }

    let_it_be(:banned_group) { create(:group) }
    let_it_be(:banned_subgroup) { create(:group, parent: banned_group) }

    before do
      stub_licensed_features(unique_project_download_limit: true)
      create(:namespace_ban, user: current_user, namespace: banned_group)
    end

    it { is_expected.to be_allowed(:read_project) }

    context 'when the user is banned from the invited group' do
      before do
        create(:project_group_link, project: project, group: banned_group)
      end

      it { is_expected.to be_disallowed(:read_project) }
    end

    context 'when the user is banned from the invited subgroup' do
      before do
        create(:project_group_link, project: project, group: banned_subgroup)
      end

      it { is_expected.to be_disallowed(:read_project) }
    end
  end

  describe 'user banned from namespace' do
    let_it_be_with_reload(:current_user) { create(:user) }

    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, :private, public_builds: false, group: group) }

    before do
      stub_licensed_features(unique_project_download_limit: true)
      project.add_developer(current_user)
    end

    context 'when user is not banned' do
      it { is_expected.to be_allowed(:read_project) }
    end

    context 'when user is banned' do
      before do
        create(:namespace_ban, user: current_user, namespace: group.root_ancestor)
      end

      it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }

      context 'as an owner of the project' do
        before do
          project.add_owner(current_user)
        end

        it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }
      end

      context 'when project is inside subgroup' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }
        let_it_be(:project) { create(:project, :private, public_builds: false, group: subgroup) }

        it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }
      end

      context 'as an admin' do
        let_it_be(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:read_project) }
        end
      end

      context 'when project is public' do
        let_it_be(:group) { create(:group, :public) }
        let_it_be(:project) { create(:project, :public, public_builds: false, group: group) }

        it { is_expected.to be_disallowed(:read_project) }
      end

      context 'when the limit_unique_project_downloads_per_namespace_user feature flag is disabled' do
        before do
          stub_feature_flags(limit_unique_project_downloads_per_namespace_user: false)
        end

        it { is_expected.to be_allowed(:read_project) }
      end

      context 'when licensed feature unique_project_download_limit is not available' do
        before do
          stub_licensed_features(unique_project_download_limit: false)
        end

        it { is_expected.to be_allowed(:read_project) }
      end
    end
  end

  describe 'create_objective' do
    let(:okr_policies) { [:create_objective, :create_key_result] }

    where(:role, :allowed) do
      :guest      | true
      :reporter   | true
      :developer  | true
      :maintainer | true
      :auditor    | false
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if role == :admin
        stub_licensed_features(okrs: true)
      end

      context 'when okrs_mvc feature flag is enabled' do
        it { is_expected.to(allowed ? be_allowed(*okr_policies) : be_disallowed(*okr_policies)) }
      end

      context 'when okrs_mvc feature flag is disabled' do
        before do
          stub_feature_flags(okrs_mvc: false)
        end

        it { is_expected.to be_disallowed(*okr_policies) }
      end

      context 'when okrs license feature is not available' do
        before do
          stub_licensed_features(okrs: false)
        end

        it { is_expected.to be_disallowed(*okr_policies) }
      end
    end
  end

  describe 'read_member_role' do
    let_it_be_with_reload(:project) { private_project_in_group }
    let_it_be_with_reload(:current_user) { create(:user) }

    let(:permission) { :read_member_role }

    where(:role, :allowed) do
      :guest      | true
      :reporter   | true
      :developer  | true
      :maintainer | true
      :auditor    | false
      :owner      | true
      :admin      | true
    end

    with_them do
      before do
        if role == :admin
          current_user.update!(admin: true)
        elsif role == :auditor
          current_user.update!(auditor: true)
        else
          create(:project_member, role, source: project, user: current_user)
        end

        enable_admin_mode!(current_user) if role == :admin
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it do
          is_expected.to(allowed ? be_allowed(permission) : be_disallowed(permission))
        end
      end

      context 'when custom_roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be_disallowed(permission) }
      end
    end
  end

  context 'hidden projects' do
    let(:project) { create(:project, :repository, hidden: true) }
    let(:current_user) { create(:user) }

    before do
      project.add_owner(current_user)
    end

    it { is_expected.to be_disallowed(:download_code) }
    it { is_expected.to be_disallowed(:build_download_code) }
  end

  context 'custom role' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:project) { private_project_in_group }
    let_it_be(:group_member_guest) do
      create(
        :group_member,
        user: guest,
        source: project.group,
        access_level: Gitlab::Access::GUEST
      )
    end

    let_it_be(:project_member_guest) do
      create(
        :project_member,
        :guest,
        user: guest,
        project: project,
        access_level: Gitlab::Access::GUEST
      )
    end

    let(:member_role_abilities) { {} }
    let(:allowed_abilities) { [] }
    let(:disallowed_abilities) { [] }
    let(:current_user) { guest }
    let(:licensed_features) { {} }

    subject { described_class.new(current_user, project) }

    def create_member_role(member, abilities = member_role_abilities)
      params = abilities.merge(namespace: project.group)

      create(:member_role, :guest, params).tap do |role|
        role.members << member
      end
    end

    shared_examples 'custom roles abilities' do
      context 'with custom_roles license disabled' do
        before do
          create_member_role(group_member_guest)

          stub_licensed_features(licensed_features.merge(custom_roles: false))
        end

        it { expect_disallowed(*allowed_abilities) }
      end

      context 'with custom_roles license enabled' do
        before do
          stub_licensed_features(licensed_features.merge(custom_roles: true))
        end

        context 'custom role for parent group' do
          context 'when a role enables the abilities' do
            before do
              create_member_role(group_member_guest)
            end

            it { expect_allowed(*allowed_abilities) }
            it { expect_disallowed(*disallowed_abilities) }
          end

          context 'when a role does not enable the abilities' do
            it { expect_disallowed(*allowed_abilities) }
          end
        end

        context 'custom role on project membership' do
          context 'when a role enables the abilities' do
            before do
              create_member_role(project_member_guest)
            end

            it { expect_allowed(*allowed_abilities) }
            it { expect_disallowed(*disallowed_abilities) }
          end

          context 'when a role does not enable the abilities' do
            it { expect_disallowed(*allowed_abilities) }
          end
        end
      end
    end

    context 'for a member role with read_code true' do
      let(:member_role_abilities) { { read_code: true } }
      let(:allowed_abilities) { [:read_code] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_runners true' do
      let(:member_role_abilities) { { admin_runners: true } }
      let(:allowed_abilities) do
        [
          :admin_runner,
          :create_runner,
          :read_runner
        ]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with read_vulnerability true' do
      let(:member_role_abilities) { { read_vulnerability: true } }
      let(:allowed_abilities) do
        [
          :access_security_and_compliance,
          :create_vulnerability_export,
          :read_security_resource,
          :read_vulnerability,
          :read_vulnerability_feedback,
          :read_vulnerability_scanner
        ]
      end

      it_behaves_like 'custom roles abilities'

      it 'does not enable to admin_vulnerability' do
        expect(subject).to be_disallowed(:admin_vulnerability)
      end
    end

    context 'for a member role with admin_terraform_state true' do
      let(:member_role_abilities) { { admin_terraform_state: true } }
      let(:allowed_abilities) { [:read_terraform_state, :admin_terraform_state] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_vulnerability true' do
      let(:member_role_abilities) { { read_vulnerability: true, admin_vulnerability: true } }
      let(:allowed_abilities) do
        [
          :admin_vulnerability,
          :create_vulnerability_feedback,
          :destroy_vulnerability_feedback,
          :read_vulnerability,
          :read_vulnerability_feedback,
          :update_vulnerability_feedback
        ]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with read_dependency true' do
      let(:member_role_abilities) { { read_dependency: true } }
      let(:allowed_abilities) { [:access_security_and_compliance, :read_dependency] }
      let(:licensed_features) { { dependency_scanning: true } }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_merge_request true' do
      let(:member_role_abilities) { { admin_merge_request: true } }
      let(:allowed_abilities) { [:admin_merge_request] }

      it_behaves_like 'custom roles abilities'

      context 'when the merge requests access level is set as private' do
        before do
          project.project_feature.update_column(:merge_requests_access_level, ProjectFeature::PRIVATE)
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'when the merge requests access level is set as disabled' do
        before do
          project.project_feature.update_column(:merge_requests_access_level, ProjectFeature::DISABLED)
        end

        it { is_expected.to be_disallowed(:read_merge_request, :admin_merge_request, :download_code) }
      end
    end

    context 'for a member role with manage_project_access_tokens true' do
      let(:member_role_abilities) { { manage_project_access_tokens: true } }
      let(:allowed_abilities) { [:manage_resource_access_tokens] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with archive_project true' do
      let(:member_role_abilities) { { archive_project: true } }
      let(:allowed_abilities) { [:archive_project, :view_edit_page] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with `remove_project` true' do
      let(:member_role_abilities) { { remove_project: true } }
      let(:allowed_abilities) { [:remove_project, :view_edit_page] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with `manage_security_policy_link` true' do
      let(:member_role_abilities) { { manage_security_policy_link: true } }
      let(:licensed_features) { { security_orchestration_policies: true } }
      let(:allowed_abilities) do
        [:read_security_orchestration_policies, :update_security_orchestration_policy_project,
         :access_security_and_compliance]
      end

      let(:disallowed_abilities) do
        [:modify_security_policy]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'when a user is assigned to custom roles in both group and project' do
      before do
        stub_licensed_features(custom_roles: true, dependency_scanning: true)

        create_member_role(group_member_guest, { read_dependency: true })
        create_member_role(project_member_guest, { read_code: true })
      end

      it { is_expected.to be_allowed(:read_dependency) }
      it { is_expected.to be_allowed(:read_code) }
    end

    context 'for a custom role with the `admin_cicd_variables` ability' do
      let(:member_role_abilities) { { admin_cicd_variables: true } }
      let(:allowed_abilities) { [:admin_cicd_variables] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `admin_push_rules` ability' do
      let(:member_role_abilities) { { admin_push_rules: true } }
      let(:allowed_abilities) { [:admin_push_rules] }

      it_behaves_like 'custom roles abilities'

      context 'when push rules feature is enabled' do
        before do
          stub_licensed_features(
            custom_roles: true,
            push_rules: true,
            commit_committer_check: true,
            commit_committer_name_check: true,
            reject_unsigned_commits: true,
            reject_non_dco_commits: true
          )

          create_member_role(group_member_guest)
        end

        it do
          expect_allowed(
            :change_push_rules,
            :read_commit_committer_check,
            :change_commit_committer_check,
            :change_commit_committer_name_check,
            :read_reject_unsigned_commits,
            :change_reject_unsigned_commits,
            :change_reject_non_dco_commits
          )
        end
      end
    end

    context 'for a member role with `custom_compliance_frameworks` true' do
      let(:licensed_features) { { compliance_framework: true } }
      let(:member_role_abilities) { { admin_compliance_framework: true } }
      let(:allowed_abilities) { [:admin_compliance_framework] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with `admin_web_hook` true' do
      let(:member_role_abilities) { { admin_web_hook: true } }
      let(:allowed_abilities) { [:admin_web_hook, :read_web_hook] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with `manage_deploy_tokens` true' do
      let(:member_role_abilities) { { manage_deploy_tokens: true } }
      let(:allowed_abilities) { [:manage_deploy_tokens, :read_deploy_token, :create_deploy_token, :destroy_deploy_token] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `manage_merge_request_settings` ability' do
      let(:member_role_abilities) { { manage_merge_request_settings: true } }
      let(:allowed_abilities) do
        [
          :manage_merge_request_settings,
          :edit_approval_rule,
          :modify_approvers_rules,
          :modify_merge_request_author_setting,
          :modify_merge_request_committer_setting
        ]
      end

      it_behaves_like 'custom roles abilities'

      context 'when `target_branch_rules` feature is available' do
        let(:licensed_features) { { target_branch_rules: true } }
        let(:allowed_abilities) { [:admin_target_branch_rule] }

        it_behaves_like 'custom roles abilities'
      end

      context 'when `merge_request_approvers` feature is available' do
        let(:licensed_features) { { merge_request_approvers: true } }
        let(:allowed_abilities) { [:admin_merge_request_approval_settings] }

        it_behaves_like 'custom roles abilities'
      end
    end

    context 'for a custom role with the `admin_integrations` ability' do
      let(:member_role_abilities) { { admin_integrations: true } }
      let(:allowed_abilities) { [:admin_integrations] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `read_runners` ability' do
      let(:member_role_abilities) { { read_runners: true } }
      let(:allowed_abilities) { [:read_project_runners, :read_runner] }

      it_behaves_like 'custom roles abilities'
    end
  end

  describe 'permissions for suggested reviewers bot', :saas do
    let(:permissions) { [:admin_project_member, :create_resource_access_tokens] }
    let(:namespace) { build_stubbed(:namespace) }
    let(:project) { build_stubbed(:project, namespace: namespace) }

    context 'when user is suggested_reviewers_bot' do
      let(:current_user) { Users::Internal.suggested_reviewers_bot }

      where(:suggested_reviewers_available, :token_creation_allowed, :allowed) do
        false | false | false
        false | true  | false
        true  | false | false
        true  | true  | true
      end

      with_them do
        before do
          allow(project).to receive(:can_suggest_reviewers?).and_return(suggested_reviewers_available)

          allow(::Gitlab::CurrentSettings)
            .to receive(:personal_access_tokens_disabled?)
            .and_return(!token_creation_allowed)
        end

        it 'always allows permissions except when feature disabled' do
          if allowed
            expect_allowed(*permissions)
          else
            expect_disallowed(*permissions)
          end
        end
      end
    end

    context 'when user is not suggested_reviewers_bot' do
      let(:current_user) { developer }

      before do
        allow(project).to receive(:can_suggest_reviewers?).and_return(true)

        allow(::Gitlab::CurrentSettings)
          .to receive(:personal_access_tokens_disabled?)
          .and_return(false)
      end

      it 'does not allow permissions' do
        expect_disallowed(*permissions)
      end
    end
  end

  describe 'read_project_runners' do
    context 'with auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_project_runners) }
    end
  end

  describe 'read_runner_usage' do
    where(:licensed, :current_user, :project, :enable_admin_mode, :clickhouse_configured, :expected) do
      true  | ref(:admin)      | ref(:public_project_in_group) | true  | true  | true
      false | ref(:maintainer) | ref(:public_project_in_group) | false | true  | false
      true  | ref(:maintainer) | ref(:public_project_in_group) | false | false | false
      true  | ref(:maintainer) | ref(:public_project_in_group) | false | true  | true
      true  | ref(:auditor)    | ref(:public_project_in_group) | false | true  | false
      true  | ref(:developer)  | ref(:public_project_in_group) | false | true  | false
      true  | ref(:admin)      | ref(:public_project)          | true  | true  | false
      true  | ref(:maintainer) | ref(:public_project)          | false | true  | false
    end

    with_them do
      before do
        stub_licensed_features(runner_performance_insights_for_namespace: licensed)

        enable_admin_mode!(admin) if enable_admin_mode

        allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
      end

      it 'matches expectation' do
        if expected
          is_expected.to be_allowed(:read_runner_usage)
        else
          is_expected.to be_disallowed(:read_runner_usage)
        end
      end
    end
  end

  describe 'workspace creation' do
    context 'with no user' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:create_workspace) }
    end

    context 'with an authorized user' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:create_workspace) }
    end
  end

  describe 'create_pipeline policy' do
    context 'as a guest member' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:create_pipeline) }

      context 'and user is a security_policy_bot' do
        let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
        let(:current_user) { security_policy_bot }

        it { is_expected.not_to be_allowed(:create_pipeline) }

        shared_examples 'allows to create pipeline' do
          let(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }

          before do
            project.add_guest(security_policy_bot)
          end

          it { is_expected.to be_allowed(:create_pipeline) }
        end

        context 'and user is a member of the project' do
          context 'and the project is private' do
            let(:project) { private_project }

            it_behaves_like 'allows to create pipeline'
          end

          context 'and the project is internal' do
            let(:project) { internal_project }

            it_behaves_like 'allows to create pipeline'
          end

          context 'and the project is public' do
            let(:project) { public_project }

            it_behaves_like 'allows to create pipeline'
          end

          context 'and the project is public in group' do
            let(:project) { public_project_in_group }

            it_behaves_like 'allows to create pipeline'
          end
        end
      end
    end
  end

  describe 'build_download_code policy' do
    let(:project) { private_project }

    context 'as a guest member' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:build_download_code) }

      context 'and user is a security_policy_bot' do
        let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
        let(:current_user) { security_policy_bot }

        it { is_expected.not_to be_allowed(:build_download_code) }

        context 'and user is a member of the project' do
          before do
            [private_project, internal_project, public_project, public_project_in_group].each do |project|
              project.add_guest(security_policy_bot)
            end
          end

          it { is_expected.to be_allowed(:build_download_code) }
        end
      end
    end
  end

  describe 'create_bot_pipeline policy' do
    context 'as a guest member' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:create_bot_pipeline) }

      context 'and user is a security_policy_bot' do
        let_it_be(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }
        let(:current_user) { security_policy_bot }

        it { is_expected.not_to be_allowed(:create_bot_pipeline) }

        context 'and user is a member of the project' do
          shared_examples 'allows to create_bot_pipeline' do
            let(:security_policy_bot) { create(:user, user_type: :security_policy_bot) }

            before do
              project.add_guest(security_policy_bot)
            end

            it { is_expected.to be_allowed(:create_bot_pipeline) }
          end

          context 'and the project is private' do
            let(:project) { private_project }

            it_behaves_like 'allows to create_bot_pipeline'
          end

          context 'and the project is internal' do
            let(:project) { internal_project }

            it_behaves_like 'allows to create_bot_pipeline'
          end

          context 'and the project is public' do
            let(:project) { public_project }

            it_behaves_like 'allows to create_bot_pipeline'
          end

          context 'and the project is public in group' do
            let(:project) { public_project_in_group }

            it_behaves_like 'allows to create_bot_pipeline'
          end
        end
      end
    end
  end

  describe 'generate_description' do
    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
    let(:current_user) { guest }
    let(:project) { private_project }

    before do
      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
    end

    context "when feature is authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(true)
      end

      context 'when user can create issue' do
        it { is_expected.to be_allowed(:generate_description) }
      end

      context 'when user cannot create issue' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_disallowed(:generate_description) }
      end
    end

    context "when feature is not authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be_disallowed(:generate_description) }
    end
  end

  describe 'summarize_new_merge_request policy' do
    let_it_be(:namespace) { group }
    let_it_be(:project) { private_project }
    let_it_be(:current_user) { maintainer }

    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    before do
      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
      allow(project).to receive(:namespace).and_return(namespace)
    end

    context "when feature is authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(true)
      end

      it { is_expected.to be_allowed(:summarize_new_merge_request) }

      context 'when add_ai_summary_for_new_mr feature flag is disabled' do
        before do
          stub_feature_flags(add_ai_summary_for_new_mr: false)
        end

        it { is_expected.to be_disallowed(:summarize_new_merge_request) }
      end

      context 'when user cannot create_merge_request_in' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:summarize_new_merge_request) }
      end
    end

    context "when feature is not authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be_disallowed(:summarize_new_merge_request) }
    end
  end

  describe 'admin_target_branch_rule policy' do
    let(:current_user) { owner }

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(target_branch_rules: false)
      end

      it { is_expected.to be_disallowed(:admin_target_branch_rule) }
    end

    describe 'when the user does not have permissions' do
      let(:current_user) { auditor }

      it { is_expected.to be_disallowed(:admin_target_branch_rule) }
    end

    describe 'when the user has permission' do
      before do
        stub_licensed_features(target_branch_rules: true)
      end

      it { is_expected.to be_allowed(:admin_target_branch_rule) }
    end
  end

  describe 'read_target_branch_rule policy' do
    let(:current_user) { owner }

    describe 'when the user has permission' do
      before do
        stub_licensed_features(target_branch_rules: true)
      end

      it { is_expected.to be_allowed(:read_target_branch_rule) }
    end
  end

  describe 'read_tracing policy' do
    let(:current_user) { reporter }

    before do
      stub_licensed_features(tracing: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_tracing: false)
      end

      it { is_expected.to be_disallowed(:read_tracing) }
    end

    describe 'when feature flag is enabled for project' do
      before do
        stub_feature_flags(observability_tracing: false)
        stub_feature_flags(observability_tracing: project)
      end

      it { is_expected.to be_allowed(:read_tracing) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_tracing: false)
        stub_feature_flags(observability_tracing: project.root_namespace)
      end

      it { is_expected.to be_allowed(:read_tracing) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(tracing: false)
      end

      it { is_expected.to be_disallowed(:read_tracing) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_tracing) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:read_tracing) }
    end
  end

  describe 'write_tracing policy' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(tracing: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_tracing: false)
      end

      it { is_expected.to be_disallowed(:write_tracing) }
    end

    describe 'when feature flag is enabled for project' do
      before do
        stub_feature_flags(observability_tracing: false)
        stub_feature_flags(observability_tracing: project)
      end

      it { is_expected.to be_allowed(:write_tracing) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_tracing: false)
        stub_feature_flags(observability_tracing: project.root_namespace)
      end

      it { is_expected.to be_allowed(:write_tracing) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(tracing: false)
      end

      it { is_expected.to be_disallowed(:write_tracing) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:write_tracing) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:write_tracing) }
    end
  end

  describe "#admin_vulnerability" do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context "with guest" do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:admin_vulnerability) }
    end

    context "with reporter" do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:admin_vulnerability) }
    end

    context "with developer" do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:admin_vulnerability) }
    end

    context "with maintainer" do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:admin_vulnerability) }
    end

    context "with owner" do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:admin_vulnerability) }
    end
  end

  describe 'read_observability_metrics policy' do
    let(:current_user) { reporter }

    before do
      stub_licensed_features(metrics_observability: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_metrics: false)
      end

      it { is_expected.to be_disallowed(:read_observability_metrics) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_metrics: false)
        stub_feature_flags(observability_metrics: project.root_namespace)
      end

      it { is_expected.to be_allowed(:read_observability_metrics) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(metrics_observability: false)
      end

      it { is_expected.to be_disallowed(:read_observability_metrics) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_observability_metrics) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:read_observability_metrics) }
    end
  end

  describe 'write_observability_metrics policy' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(metrics_observability: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_metrics: false)
      end

      it { is_expected.to be_disallowed(:write_observability_metrics) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_metrics: false)
        stub_feature_flags(observability_metrics: project.root_namespace)
      end

      it { is_expected.to be_allowed(:write_observability_metrics) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(metrics_observability: false)
      end

      it { is_expected.to be_disallowed(:write_observability_metrics) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:write_observability_metrics) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:write_observability_metrics) }
    end
  end

  describe 'read_observability_logs policy' do
    let(:current_user) { reporter }

    before do
      stub_licensed_features(logs_observability: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_logs: false)
      end

      it { is_expected.to be_disallowed(:read_observability_logs) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_logs: false)
        stub_feature_flags(observability_logs: project.root_namespace)
      end

      it { is_expected.to be_allowed(:read_observability_logs) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(logs_observability: false)
      end

      it { is_expected.to be_disallowed(:read_observability_logs) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_observability_logs) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:read_observability_logs) }
    end
  end

  describe 'write_observability_logs policy' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(logs_observability: true)
    end

    describe 'when feature flag is disabled' do
      before do
        stub_feature_flags(observability_logs: false)
      end

      it { is_expected.to be_disallowed(:write_observability_logs) }
    end

    describe 'when feature flag is enabled for root namespace' do
      before do
        stub_feature_flags(observability_logs: false)
        stub_feature_flags(observability_logs: project.root_namespace)
      end

      it { is_expected.to be_allowed(:write_observability_logs) }
    end

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(logs_observability: false)
      end

      it { is_expected.to be_disallowed(:write_observability_logs) }
    end

    describe 'when the user does not have permission' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:write_observability_logs) }
    end

    describe 'when the user has permission' do
      it { is_expected.to be_allowed(:write_observability_logs) }
    end
  end

  describe 'generate_cube_query policy' do
    let(:current_user) { owner }

    where(:ai_global_switch, :flag_enabled, :licensed, :allowed) do
      true | true | true | true
      true | true | false | false
      true | false | true | false
      true | false | false | false
      false | true | true | false
      false | true | false | false
      false | false | true | false
      false | false | false | false
    end

    with_them do
      before do
        stub_feature_flags(ai_global_switch: ai_global_switch)
        stub_feature_flags(generate_cube_query: flag_enabled)
        stub_licensed_features(ai_generate_cube_query: licensed)
      end

      it 'permits the correct abilities' do
        if allowed
          is_expected.to be_allowed(:generate_cube_query)
        else
          is_expected.to be_disallowed(:generate_cube_query)
        end
      end
    end
  end

  describe 'read_ai_agents' do
    where(:feature_flag_enabled, :licensed_feature, :current_user, :allowed) do
      true  | true  | ref(:owner)      | true
      true  | true  | ref(:reporter)   | true
      true  | true  | ref(:guest)      | true
      true  | true  | ref(:non_member) | false
      true  | false | ref(:owner)      | false
      true  | false | ref(:reporter)   | false
      true  | false | ref(:guest)      | false
      true  | false | ref(:non_member) | false
      false | true  | ref(:owner)      | false
      false | true  | ref(:reporter)   | false
      false | true  | ref(:guest)      | false
      false | true  | ref(:non_member) | false
      false | false | ref(:owner)      | false
      false | false | ref(:reporter)   | false
      false | false | ref(:guest)      | false
      false | false | ref(:non_member) | false
    end
    with_them do
      before do
        stub_feature_flags(agent_registry: feature_flag_enabled)
        stub_licensed_features(ai_agents: licensed_feature)
      end

      if params[:allowed]
        it { expect_allowed(:read_ai_agents) }
      else
        it { expect_disallowed(:read_ai_agents) }
      end
    end
  end

  describe 'write_ai_agents' do
    where(:feature_flag_enabled, :licensed_feature, :current_user, :allowed) do
      true  | true  | ref(:owner)      | true
      true  | true  | ref(:reporter)   | true
      true  | true  | ref(:guest)      | false
      true  | true  | ref(:non_member) | false
      true  | false | ref(:owner)      | false
      true  | false | ref(:reporter)   | false
      true  | false | ref(:guest)      | false
      true  | false | ref(:non_member) | false
      false | true  | ref(:owner)      | false
      false | true  | ref(:reporter)   | false
      false | true  | ref(:guest)      | false
      false | true  | ref(:non_member) | false
      false | false | ref(:owner)      | false
      false | false | ref(:reporter)   | false
      false | false | ref(:guest)      | false
      false | false | ref(:non_member) | false
    end
    with_them do
      before do
        stub_feature_flags(agent_registry: feature_flag_enabled)
        stub_licensed_features(ai_agents: licensed_feature)
      end

      if params[:allowed]
        it { expect_allowed(:write_ai_agents) }
      else
        it { expect_disallowed(:write_ai_agents) }
      end
    end
  end

  describe 'access_duo_chat' do
    let_it_be(:current_user) { create(:user) }
    let(:project) { create(:project, :public, group: group) }

    subject { described_class.new(current_user, project) }

    context 'when on SaaS instance', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with duo features enabled and ai chat available for group on SaaS'

        context 'when user is a member of the group' do
          before do
            stub_feature_flags(duo_chat_requires_licensed_seat: false)
            group.add_guest(current_user)
          end

          it { is_expected.to be_allowed(:access_duo_chat) }

          context 'when the group does not have an Premium SaaS license' do
            let_it_be(:group) { create(:group) }

            it { is_expected.to be_disallowed(:access_duo_chat) }
          end
        end

        context 'when user is not a member of the parent group' do
          context 'when the user has AI enabled via another group' do
            before do
              allow(current_user).to receive(:any_group_with_ai_chat_available?).and_return(true)
            end

            context 'user can view project' do
              it 'is allowed' do
                is_expected.to be_allowed(:access_duo_chat)
              end
            end

            context 'user cannot view project' do
              before do
                project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
              end

              it 'is not allowed' do
                is_expected.to be_disallowed(:access_duo_chat)
              end
            end
          end
        end

        context 'when user is a member of the project' do
          before do
            project.add_guest(current_user)
          end

          context 'when the user has AI enabled through parent group' do
            it 'is allowed' do
              allow(current_user).to receive(:any_group_with_ai_chat_available?).and_return(true)

              is_expected.to be_allowed(:access_duo_chat)
            end
          end
        end
      end
    end

    context 'for self-managed', :with_cloud_connector do
      let_it_be_with_reload(:group) { create(:group) }
      let(:policy) { :access_duo_chat }

      before do
        project.add_guest(current_user)
      end

      context 'when not on .org or .com' do
        where(:licensed, :duo_features_enabled, :duo_chat_matcher) do
          true  | false | be_disallowed(policy)
          true  | true  | be_allowed(policy)
          false | false | be_disallowed(policy)
          false | true  | be_disallowed(policy)
        end

        with_them do
          before do
            allow(::Gitlab).to receive(:org_or_com?).and_return(false)
            stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
            stub_licensed_features(ai_chat: licensed)
          end

          it { is_expected.to duo_chat_matcher }
        end
      end
    end
  end

  context 'access_duo_features' do
    let(:project) { private_project }

    where(:current_user, :duo_features_enabled, :cs_matcher) do
      ref(:guest) | true | be_allowed(:access_duo_features)
      ref(:guest) | false | be_disallowed(:access_duo_features)
      nil | true | be_disallowed(:access_duo_features)
      nil | false | be_disallowed(:access_duo_features)
    end

    with_them do
      before do
        project.update!(duo_features_enabled: duo_features_enabled)
      end

      it do
        is_expected.to cs_matcher
      end
    end
  end

  describe 'on_demand_scans_enabled policy' do
    let(:current_user) { owner }
    let(:permissions) { [:read_on_demand_dast_scan, :create_on_demand_dast_scan, :edit_on_demand_dast_scan] }

    where(:feature_available, :fips_enabled, :browser_based_ff_enabled, :allowed) do
      false | false | false | false
      false | false | true | false
      true | false | false | true
      true | false | true | true
      true | true | false | false
      true | true | true | true
    end

    with_them do
      context "when feature is #{params[:feature_available] ? 'available' : 'unavailable'}" do
        before do
          stub_licensed_features(security_on_demand_scans: feature_available)
        end

        describe "when FIPS is #{params[:fips_enabled] ? 'enabled' : 'disabled'}" do
          before do
            allow(::Gitlab::FIPS).to receive(:enabled?).and_return(fips_enabled)
          end

          describe "when browser based on demand scan feature flag is #{params[:browser_based_ff_enabled] ? 'enabled' : 'disabled'}" do
            before do
              stub_feature_flags(dast_ods_browser_based_scanner: browser_based_ff_enabled)
            end

            it "on demand scan permissions are #{params[:allowed] ? 'allowed' : 'disallowed'}" do
              if allowed
                expect_allowed(*permissions)
              else
                expect_disallowed(*permissions)
              end
            end
          end
        end
      end
    end
  end

  describe 'read_runner_cloud_provisioning_info policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_runner_cloud_provisioning_info) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }
      end
    end
  end

  describe 'provision_cloud_runner policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:provision_cloud_runner) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:provision_cloud_runner) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:provision_cloud_runner) }
      end
    end
  end

  describe 'read_google_cloud_artifact_registry' do
    where(:saas_feature_enabled, :current_user, :match_expected_result) do
      true  | ref(:owner)      | be_allowed(:read_google_cloud_artifact_registry)
      true  | ref(:reporter)   | be_allowed(:read_google_cloud_artifact_registry)
      true  | ref(:guest)      | be_disallowed(:read_google_cloud_artifact_registry)
      true  | ref(:non_member) | be_disallowed(:read_google_cloud_artifact_registry)
      false | ref(:owner)      | be_disallowed(:read_google_cloud_artifact_registry)
      false | ref(:reporter)   | be_disallowed(:read_google_cloud_artifact_registry)
      false | ref(:guest)      | be_disallowed(:read_google_cloud_artifact_registry)
      false | ref(:non_member) | be_disallowed(:read_google_cloud_artifact_registry)
    end

    with_them do
      before do
        stub_saas_features(google_cloud_support: saas_feature_enabled)
      end

      it { is_expected.to match_expected_result }
    end
  end

  describe 'admin_google_cloud_artifact_registry' do
    where(:saas_feature_enabled, :current_user, :match_expected_result) do
      true  | ref(:owner)      | be_allowed(:admin_google_cloud_artifact_registry)
      true  | ref(:maintainer) | be_allowed(:admin_google_cloud_artifact_registry)
      true  | ref(:developer)  | be_disallowed(:admin_google_cloud_artifact_registry)
      true  | ref(:non_member) | be_disallowed(:admin_google_cloud_artifact_registry)
      false | ref(:owner)      | be_disallowed(:admin_google_cloud_artifact_registry)
      false | ref(:maintainer) | be_disallowed(:admin_google_cloud_artifact_registry)
      false | ref(:developer)  | be_disallowed(:admin_google_cloud_artifact_registry)
      false | ref(:non_member) | be_disallowed(:admin_google_cloud_artifact_registry)
    end

    with_them do
      before do
        stub_saas_features(google_cloud_support: saas_feature_enabled)
      end

      it { is_expected.to match_expected_result }
    end
  end

  context 'saved replies permissions' do
    let(:current_user) { owner }

    context 'when project_saved_replies_flag feature flag is disabled' do
      before do
        stub_feature_flags(project_saved_replies_flag: false)
      end

      it { is_expected.to be_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
    end

    context 'when no license is present' do
      before do
        stub_licensed_features(project_saved_replies: false)
      end

      it { is_expected.to be_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
    end

    context 'with correct license' do
      before do
        stub_licensed_features(project_saved_replies: true)
      end

      it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a guest member of the project' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end
    end
  end

  describe 'enable_pre_receive_secret_detection' do
    where(:dedicated_instance, :pre_receive_secret_detection_actor, :current_user, :match_expected_result) do
      false | project | ref(:owner)      | be_allowed(:enable_pre_receive_secret_detection)
      false | project | ref(:maintainer) | be_allowed(:enable_pre_receive_secret_detection)
      false | project | ref(:developer)  | be_disallowed(:enable_pre_receive_secret_detection)
      false | project | ref(:non_member) | be_disallowed(:enable_pre_receive_secret_detection)
      false | false   | ref(:owner)      | be_disallowed(:enable_pre_receive_secret_detection)
      false | false   | ref(:maintainer) | be_disallowed(:enable_pre_receive_secret_detection)
      false | false   | ref(:developer)  | be_disallowed(:enable_pre_receive_secret_detection)
      false | false   | ref(:non_member) | be_disallowed(:enable_pre_receive_secret_detection)
      true  | false   | ref(:owner)      | be_allowed(:enable_pre_receive_secret_detection)
      true  | false   | ref(:maintainer) | be_allowed(:enable_pre_receive_secret_detection)
      true  | false   | ref(:developer)  | be_disallowed(:enable_pre_receive_secret_detection)
      true  | false   | ref(:non_member) | be_disallowed(:enable_pre_receive_secret_detection)
    end

    with_them do
      before do
        stub_feature_flags(pre_receive_secret_detection_push_check: pre_receive_secret_detection_actor)
        stub_application_setting(gitlab_dedicated_instance: dedicated_instance)
      end

      it { is_expected.to match_expected_result }
    end
  end

  describe 'start_duo_workflows' do
    where(:start_duo_workflows_feature_flag, :current_user, :match_expected_result) do
      true  | ref(:owner)      | be_allowed(:start_duo_workflows)
      true  | ref(:maintainer) | be_allowed(:start_duo_workflows)
      true  | ref(:developer)  | be_allowed(:start_duo_workflows)
      true  | ref(:guest)      | be_disallowed(:start_duo_workflows)
      true  | ref(:non_member) | be_disallowed(:start_duo_workflows)
      false | ref(:owner)      | be_disallowed(:start_duo_workflows)
      false | ref(:maintainer) | be_disallowed(:start_duo_workflows)
      false | ref(:developer)  | be_disallowed(:start_duo_workflows)
      false | ref(:guest)      | be_disallowed(:start_duo_workflows)
      false | ref(:non_member) | be_disallowed(:start_duo_workflows)
    end

    with_them do
      before do
        stub_feature_flags(start_duo_workflows: start_duo_workflows_feature_flag)
      end

      it { is_expected.to match_expected_result }
    end
  end

  describe 'enable_container_scanning_for_registry' do
    where(:container_scanning_for_registry, :current_user, :match_expected_result) do
      true  | ref(:owner)      | be_allowed(:enable_container_scanning_for_registry)
      true  | ref(:maintainer) | be_allowed(:enable_container_scanning_for_registry)
      true  | ref(:developer)  | be_disallowed(:enable_container_scanning_for_registry)
      true  | ref(:non_member) | be_disallowed(:enable_container_scanning_for_registry)
      false | ref(:owner)      | be_disallowed(:enable_container_scanning_for_registry)
      false | ref(:maintainer) | be_disallowed(:enable_container_scanning_for_registry)
      false | ref(:developer)  | be_disallowed(:enable_container_scanning_for_registry)
      false | ref(:non_member) | be_disallowed(:enable_container_scanning_for_registry)
    end

    with_them do
      before do
        stub_feature_flags(container_scanning_for_registry_flag: container_scanning_for_registry)
      end

      it { is_expected.to match_expected_result }
    end
  end
end
