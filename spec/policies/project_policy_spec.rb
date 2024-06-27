# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectPolicy, feature_category: :system_access do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper
  include_context 'ProjectPolicy context'

  let_it_be_with_reload(:project_with_runner_registration_token) do
    create(:project, :public, :allow_runner_registration_token)
  end

  let(:project) { public_project }

  subject { described_class.new(current_user, project) }

  before_all do
    project_with_runner_registration_token.add_guest(guest)
    project_with_runner_registration_token.add_reporter(reporter)
    project_with_runner_registration_token.add_developer(developer)
    project_with_runner_registration_token.add_maintainer(maintainer)
    project_with_runner_registration_token.add_owner(owner)
  end

  def expect_allowed(*permissions)
    permissions.each { |p| is_expected.to be_allowed(p) }
  end

  def expect_disallowed(*permissions)
    permissions.each { |p| is_expected.not_to be_allowed(p) }
  end

  context 'with no project feature' do
    let(:current_user) { owner }

    before do
      project.project_feature.destroy!
      project.reload
    end

    it 'returns false' do
      is_expected.to be_disallowed(:read_build)
    end
  end

  it 'does not include the read permissions when the issue author is not a member of the private project' do
    project = create(:project, :private)
    issue   = create(:issue, project: project, author: create(:user))
    user    = issue.author

    expect(project.team.member?(issue.author)).to be false

    expect(Ability).not_to be_allowed(user, :read_issue, project)
    expect(Ability).not_to be_allowed(user, :read_work_item, project)
  end

  it_behaves_like 'model with wiki policies' do
    let(:container) { project }
    let_it_be(:user) { owner }

    def set_access_level(access_level)
      project.project_feature.update_attribute(:wiki_access_level, access_level)
    end
  end

  context 'issues feature' do
    let(:current_user) { owner }

    context 'when the feature is disabled' do
      before do
        project.issues_enabled = false
        project.save!
      end

      it 'does not include the issues permissions' do
        expect_disallowed :read_issue, :read_issue_iid, :create_issue, :update_issue, :admin_issue, :create_incident, :create_work_item, :create_task, :read_work_item
      end

      it 'disables boards and lists permissions' do
        expect_disallowed :read_issue_board, :create_board, :update_board
        expect_disallowed :read_issue_board_list, :create_list, :update_list, :admin_issue_board_list
      end

      context 'when external tracker configured' do
        it 'does not include the issues permissions' do
          create(:jira_integration, project: project)

          expect_disallowed :read_issue, :read_issue_iid, :create_issue, :update_issue, :admin_issue, :create_incident, :create_work_item, :create_task, :read_work_item
        end
      end
    end
  end

  context 'merge requests feature' do
    let(:current_user) { owner }
    let(:mr_permissions) do
      [:create_merge_request_from, :read_merge_request, :update_merge_request,
       :admin_merge_request, :create_merge_request_in]
    end

    it 'disallows all permissions when the feature is disabled' do
      project.project_feature.update!(merge_requests_access_level: ProjectFeature::DISABLED)

      expect_disallowed(*mr_permissions)
    end

    context 'for a guest in a private project' do
      let(:current_user) { guest }
      let(:project) { private_project }

      it 'disallows the guest from all merge request permissions' do
        expect_disallowed(*mr_permissions)
      end
    end
  end

  context 'when both issues and merge requests are disabled' do
    let(:current_user) { owner }

    before do
      project.issues_enabled = false
      project.merge_requests_enabled = false
      project.save!
    end

    it 'does not include the issues permissions' do
      expect_disallowed :read_cycle_analytics
    end
  end

  context 'creating_merge_request_in' do
    context 'when the current_user can download_code' do
      before do
        expect(subject).to receive(:allowed?).with(:download_code).and_return(true)
        allow(subject).to receive(:allowed?).with(any_args).and_call_original
      end

      context 'when project is public' do
        let(:project) { public_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:create_merge_request_in) }
        end
      end

      context 'when project is internal' do
        let(:project) { internal_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:create_merge_request_in) }
        end
      end

      context 'when project is private' do
        let(:project) { private_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.not_to be_allowed(:create_merge_request_in) }
        end

        context 'when the current_user is reporter or above' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:create_merge_request_in) }
        end
      end
    end

    context 'when the current_user can not download code' do
      before do
        expect(subject).to receive(:allowed?).with(:download_code).and_return(false)
        allow(subject).to receive(:allowed?).with(any_args).and_call_original
      end

      context 'when project is public' do
        let(:project) { public_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.not_to be_allowed(:create_merge_request_in) }
        end
      end

      context 'when project is internal' do
        let(:project) { internal_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.not_to be_allowed(:create_merge_request_in) }
        end
      end

      context 'when project is private' do
        let(:project) { private_project }

        context 'when the current_user is guest' do
          let(:current_user) { guest }

          it { is_expected.not_to be_allowed(:create_merge_request_in) }
        end

        context 'when the current_user is reporter or above' do
          let(:current_user) { reporter }

          it { is_expected.not_to be_allowed(:create_merge_request_in) }
        end
      end
    end
  end

  context 'pipeline feature' do
    let(:project)      { private_project }
    let(:current_user) { developer }
    let(:pipeline)     { create(:ci_pipeline, project: project) }

    describe 'for confirmed user' do
      it 'allows modify pipelines' do
        expect_allowed(:create_pipeline)
        expect_allowed(:update_pipeline)
        expect_allowed(:cancel_pipeline)
        expect_allowed(:create_pipeline_schedule)
        expect_allowed(:read_ci_pipeline_schedules_plan_limit)
      end
    end

    describe 'for unconfirmed user' do
      let(:current_user) { project.first_owner.tap { |u| u.update!(confirmed_at: nil) } }

      it 'disallows to modify pipelines' do
        expect_disallowed(:create_pipeline)
        expect_disallowed(:update_pipeline)
        expect_disallowed(:cancel_pipeline)
        expect_disallowed(:destroy_pipeline)
        expect_disallowed(:create_pipeline_schedule)
        expect_disallowed(:read_ci_pipeline_schedules_plan_limit)
      end
    end

    describe 'destroy permission' do
      describe 'for developers' do
        it 'prevents :destroy_pipeline' do
          expect(current_user.can?(:destroy_pipeline, pipeline)).to be_falsey
        end
      end

      describe 'for maintainers' do
        let(:current_user) { maintainer }

        it 'prevents :destroy_pipeline' do
          project.add_maintainer(maintainer)
          expect(current_user.can?(:destroy_pipeline, pipeline)).to be_falsey
        end
      end

      describe 'for project owner' do
        let(:current_user) { project.first_owner }

        it 'allows :destroy_pipeline' do
          expect(current_user.can?(:destroy_pipeline, pipeline)).to be_truthy
        end

        context 'on archived projects' do
          before do
            project.update!(archived: true)
          end

          it 'prevents :destroy_pipeline' do
            expect(current_user.can?(:destroy_pipeline, pipeline)).to be_falsey
          end
        end

        context 'on archived pending_delete projects' do
          before do
            project.update!(archived: true, pending_delete: true)
          end

          it 'allows :destroy_pipeline' do
            expect(current_user.can?(:destroy_pipeline, pipeline)).to be_truthy
          end
        end
      end
    end
  end

  context 'builds feature' do
    context 'when builds are disabled' do
      let(:current_user) { owner }

      before do
        project.project_feature.update!(builds_access_level: ProjectFeature::DISABLED)
      end

      it 'disallows all permissions except pipeline when the feature is disabled' do
        builds_permissions = [
          :create_build, :read_build, :update_build, :cancel_build, :admin_build, :destroy_build,
          :create_pipeline_schedule, :read_pipeline_schedule_variables, :update_pipeline_schedule, :admin_pipeline_schedule, :destroy_pipeline_schedule,
          :create_environment, :read_environment, :update_environment, :admin_environment, :destroy_environment,
          :create_deployment, :read_deployment, :update_deployment, :admin_deployment, :destroy_deployment
        ]

        expect_disallowed(*builds_permissions)
      end
    end

    context 'when builds are disabled only for some users' do
      let(:current_user) { guest }

      before do
        project.project_feature.update!(builds_access_level: ProjectFeature::PRIVATE)
      end

      it 'disallows pipeline and commit_status permissions' do
        builds_permissions = [
          :create_pipeline, :update_pipeline, :cancel_pipeline, :admin_pipeline, :destroy_pipeline,
          :create_commit_status, :update_commit_status, :admin_commit_status, :destroy_commit_status
        ]

        expect_disallowed(*builds_permissions)
      end
    end
  end

  context 'repository feature' do
    let(:repository_permissions) do
      [
        :create_pipeline, :update_pipeline, :cancel_pipeline, :admin_pipeline, :destroy_pipeline,
        :create_build, :read_build, :cancel_build, :update_build, :admin_build, :destroy_build,
        :create_pipeline_schedule, :read_pipeline_schedule, :update_pipeline_schedule, :admin_pipeline_schedule, :destroy_pipeline_schedule,
        :create_environment, :read_environment, :update_environment, :admin_environment, :destroy_environment,
        :create_cluster, :read_cluster, :update_cluster, :admin_cluster,
        :create_deployment, :read_deployment, :update_deployment, :admin_deployment, :destroy_deployment,
        :download_code, :build_download_code
      ]
    end

    context 'when user is a project member' do
      let(:current_user) { owner }

      context 'when it is disabled' do
        before do
          project.project_feature.update!(
            repository_access_level: ProjectFeature::DISABLED,
            merge_requests_access_level: ProjectFeature::DISABLED,
            builds_access_level: ProjectFeature::DISABLED,
            forking_access_level: ProjectFeature::DISABLED
          )
        end

        it 'disallows all permissions' do
          expect_disallowed(*repository_permissions)
        end
      end
    end

    context 'when user is non-member' do
      let(:current_user) { non_member }

      context 'when access level is private' do
        before do
          project.project_feature.update!(
            repository_access_level: ProjectFeature::PRIVATE,
            merge_requests_access_level: ProjectFeature::PRIVATE,
            builds_access_level: ProjectFeature::PRIVATE,
            forking_access_level: ProjectFeature::PRIVATE
          )
        end

        it 'disallows all permissions' do
          expect_disallowed(*repository_permissions)
        end
      end
    end
  end

  it_behaves_like 'project policies as anonymous'
  it_behaves_like 'project policies as guest'
  it_behaves_like 'project policies as reporter'
  it_behaves_like 'project policies as developer'
  it_behaves_like 'project policies as maintainer'
  it_behaves_like 'project policies as owner'
  it_behaves_like 'project policies as organization owner'
  it_behaves_like 'project policies as admin with admin mode'
  it_behaves_like 'project policies as admin without admin mode'

  context 'when a public project has merge requests allowing access' do
    include ProjectForksHelper
    let(:current_user) { create(:user) }
    let(:target_project) { create(:project, :public) }
    let(:project) { fork_project(target_project) }
    let!(:merge_request) do
      create(
        :merge_request,
        target_project: target_project,
        source_project: project,
        allow_collaboration: true
      )
    end

    let(:maintainer_abilities) do
      %w[create_build create_pipeline]
    end

    it 'does not allow pushing code' do
      expect_disallowed(*maintainer_abilities)
    end

    it 'allows pushing if the user is a member with push access to the target project' do
      target_project.add_developer(current_user)

      expect_allowed(*maintainer_abilities)
    end

    it 'disallows abilities to a maintainer if the merge request was closed' do
      target_project.add_developer(current_user)
      merge_request.close!

      expect_disallowed(*maintainer_abilities)
    end
  end

  context 'importing members from another project' do
    %w[maintainer owner].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_allowed(:import_project_members_from_another_project) }
      end
    end

    %w[guest reporter developer anonymous].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_disallowed(:import_project_members_from_another_project) }
      end
    end

    context 'with an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:import_project_members_from_another_project) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:import_project_members_from_another_project) }
      end
    end
  end

  context 'importing work items' do
    %w[reporter developer maintainer owner].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_allowed(:import_work_items) }
      end
    end

    %w[guest anonymous].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_disallowed(:import_work_items) }
      end
    end

    context 'with an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:import_work_items) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:import_work_items) }
      end
    end
  end

  context 'reading usage quotas and viewing the edit page' do
    %w[maintainer owner].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_allowed(:read_usage_quotas, :view_edit_page) }
      end
    end

    %w[guest reporter developer anonymous].each do |role|
      context "with #{role}" do
        let(:current_user) { send(role) }

        it { is_expected.to be_disallowed(:read_usage_quotas, :view_edit_page) }
      end
    end

    context 'with an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:read_usage_quotas, :view_edit_page) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:read_usage_quotas, :view_edit_page) }
      end
    end
  end

  it_behaves_like 'clusterable policies' do
    let_it_be(:clusterable) { create(:project, :repository) }
    let_it_be(:cluster) do
      create(:cluster, :provided_by_gcp, :project, projects: [clusterable])
    end
  end

  context 'owner access' do
    let_it_be(:owner_user) { owner }
    let_it_be(:owner_of_different_thing) { create(:user) }

    context 'personal project' do
      let_it_be(:project) { private_project }
      let_it_be(:project2) { create(:project) }

      before_all do
        project.add_guest(guest)
        project.add_reporter(reporter)
        project.add_developer(developer)
        project.add_maintainer(maintainer)
        project2.add_owner(owner_of_different_thing)
      end

      it 'allows owner access', :aggregate_failures do
        expect(described_class.new(owner_of_different_thing, project)).to be_disallowed(:owner_access)
        expect(described_class.new(non_member, project)).to be_disallowed(:owner_access)
        expect(described_class.new(guest, project)).to be_disallowed(:owner_access)
        expect(described_class.new(reporter, project)).to be_disallowed(:owner_access)
        expect(described_class.new(developer, project)).to be_disallowed(:owner_access)
        expect(described_class.new(maintainer, project)).to be_disallowed(:owner_access)
        expect(described_class.new(project.owner, project)).to be_allowed(:owner_access)
      end
    end

    context 'group project' do
      let_it_be(:project) { private_project_in_group }
      let_it_be(:group2) { create(:group) }
      let_it_be(:group) { project.group }

      context 'group members' do
        before_all do
          group.add_guest(guest)
          group.add_reporter(reporter)
          group.add_developer(developer)
          group.add_maintainer(maintainer)
          group.add_owner(owner_user)
          group2.add_owner(owner_of_different_thing)
        end

        it 'allows owner access', :aggregate_failures do
          expect(described_class.new(owner_of_different_thing, project)).to be_disallowed(:owner_access)
          expect(described_class.new(non_member, project)).to be_disallowed(:owner_access)
          expect(described_class.new(guest, project)).to be_disallowed(:owner_access)
          expect(described_class.new(reporter, project)).to be_disallowed(:owner_access)
          expect(described_class.new(developer, project)).to be_disallowed(:owner_access)
          expect(described_class.new(maintainer, project)).to be_disallowed(:owner_access)
          expect(described_class.new(owner_user, project)).to be_allowed(:owner_access)
        end
      end
    end
  end

  context 'with timeline event tags' do
    context 'when user is member of the project' do
      it 'allows access to timeline event tags' do
        expect(described_class.new(owner, project)).to be_allowed(:read_incident_management_timeline_event_tag)
        expect(described_class.new(developer, project)).to be_allowed(:read_incident_management_timeline_event_tag)
        expect(described_class.new(guest, project)).to be_allowed(:read_incident_management_timeline_event_tag)
        expect(described_class.new(admin, project)).to be_allowed(:read_incident_management_timeline_event_tag)
      end
    end

    context 'when user is a maintainer/owner' do
      it 'allows to create timeline event tags' do
        expect(described_class.new(maintainer, project)).to be_allowed(:admin_incident_management_timeline_event_tag)
        expect(described_class.new(owner, project)).to be_allowed(:admin_incident_management_timeline_event_tag)
      end

      it 'allows to read import error' do
        expect(described_class.new(maintainer, project)).to be_allowed(:read_import_error)
        expect(described_class.new(owner, project)).to be_allowed(:read_import_error)
      end
    end

    context 'when user is a developer/guest/reporter' do
      it 'disallows creation' do
        expect(described_class.new(developer, project)).to be_disallowed(:admin_incident_management_timeline_event_tag)
        expect(described_class.new(guest, project)).to be_disallowed(:admin_incident_management_timeline_event_tag)
        expect(described_class.new(reporter, project)).to be_disallowed(:admin_incident_management_timeline_event_tag)
      end

      it 'disallows reading the import error' do
        expect(described_class.new(developer, project)).to be_disallowed(:read_import_error)
        expect(described_class.new(guest, project)).to be_disallowed(:read_import_error)
        expect(described_class.new(reporter, project)).to be_disallowed(:read_import_error)
      end
    end

    context 'when user is not a member of the project' do
      let(:project) { private_project }

      it 'disallows access to the timeline event tags' do
        expect(described_class.new(non_member, project)).to be_disallowed(:read_incident_management_timeline_event_tag)
        expect(described_class.new(non_member, project)).to be_disallowed(:admin_incident_management_timeline_event_tag)
      end
    end
  end

  context 'reading a project' do
    it 'allows access when a user has read access to the repo' do
      expect(described_class.new(owner, project)).to be_allowed(:read_project)
      expect(described_class.new(developer, project)).to be_allowed(:read_project)
      expect(described_class.new(admin, project)).to be_allowed(:read_project)
    end

    it 'never checks the external service' do
      expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

      expect(described_class.new(owner, project)).to be_allowed(:read_project)
    end

    context 'with an external authorization service' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows access when the external service allows it' do
        external_service_allow_access(owner, project)
        external_service_allow_access(developer, project)

        expect(described_class.new(owner, project)).to be_allowed(:read_project)
        expect(described_class.new(developer, project)).to be_allowed(:read_project)
      end

      context 'with an admin' do
        context 'when admin mode is enabled', :enable_admin_mode do
          it 'does not check the external service and allows access' do
            expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

            expect(described_class.new(admin, project)).to be_allowed(:read_project)
          end
        end

        context 'when admin mode is disabled' do
          it 'checks the external service and allows access' do
            external_service_allow_access(admin, project)

            expect(::Gitlab::ExternalAuthorization).to receive(:access_allowed?)

            expect(described_class.new(admin, project)).to be_allowed(:read_project)
          end
        end
      end

      it 'prevents all but seeing a public project in a list when access is denied' do
        [developer, owner, build(:user), nil].each do |user|
          external_service_deny_access(user, project)
          policy = described_class.new(user, project)

          expect(policy).not_to be_allowed(:read_project)
          expect(policy).not_to be_allowed(:owner_access)
          expect(policy).not_to be_allowed(:change_namespace)
        end
      end

      it 'passes the full path to external authorization for logging purposes' do
        expect(::Gitlab::ExternalAuthorization)
          .to receive(:access_allowed?).with(owner, 'default_label', project.full_path).and_call_original

        described_class.new(owner, project).allowed?(:read_project)
      end
    end
  end

  context 'forking a project' do
    context 'anonymous user' do
      let(:current_user) { anonymous }

      it { is_expected.to be_disallowed(:fork_project) }
    end

    context 'project member' do
      let(:project) { private_project }

      context 'guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:fork_project) }
      end

      %w[reporter developer maintainer].each do |role|
        context role do
          let(:current_user) { send(role) }

          it { is_expected.to be_allowed(:fork_project) }
        end
      end
    end
  end

  describe 'create_task' do
    context 'when user is member of the project' do
      let(:current_user) { developer }

      it { expect_allowed(:create_task) }
    end
  end

  describe 'read_grafana', feature_category: :metrics do
    using RSpec::Parameterized::TableSyntax

    let(:policy) { :read_grafana }

    where(:project_visibility, :role, :allowed) do
      :public   | :anonymous | false
      :public   | :guest     | false
      :public   | :reporter  | true
      :internal | :anonymous | false
      :internal | :guest     | true
      :internal | :reporter  | true
      :private  | :anonymous | false
      :private  | :guest     | true
      :private  | :reporter  | true
    end

    with_them do
      let(:current_user) { public_send(role) }
      let(:project) { public_send("#{project_visibility}_project") }

      if params[:allowed]
        it { is_expected.to be_allowed(policy) }
      else
        it { is_expected.not_to be_allowed(policy) }
      end
    end
  end

  describe 'read_prometheus', feature_category: :metrics do
    using RSpec::Parameterized::TableSyntax

    before do
      project.project_feature.update!(metrics_dashboard_access_level: ProjectFeature::ENABLED)
    end

    let(:policy) { :read_prometheus }

    where(:project_visibility, :role, :allowed) do
      :public   | :anonymous | false
      :public   | :guest     | false
      :public   | :reporter  | true
      :internal | :anonymous | false
      :internal | :guest     | false
      :internal | :reporter  | true
      :private  | :anonymous | false
      :private  | :guest     | false
      :private  | :reporter  | true
    end

    with_them do
      let(:current_user) { public_send(role) }
      let(:project) { public_send("#{project_visibility}_project") }

      if params[:allowed]
        it { is_expected.to be_allowed(policy) }
      else
        it { is_expected.not_to be_allowed(policy) }
      end
    end
  end

  describe 'update_max_artifacts_size' do
    context 'when no user' do
      let(:current_user) { anonymous }

      it { expect_disallowed(:update_max_artifacts_size) }
    end

    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:update_max_artifacts_size) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:update_max_artifacts_size) }
      end
    end

    %w[guest reporter developer maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it { expect_disallowed(:update_max_artifacts_size) }
      end
    end
  end

  describe 'read_storage_disk_path' do
    context 'when no user' do
      let(:current_user) { anonymous }

      it { expect_disallowed(:read_storage_disk_path) }
    end

    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:read_storage_disk_path) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:read_storage_disk_path) }
      end
    end

    %w[guest reporter developer maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it { expect_disallowed(:read_storage_disk_path) }
      end
    end
  end

  context 'alert bot' do
    let(:current_user) { Users::Internal.alert_bot }

    it { is_expected.to be_allowed(:reporter_access) }

    context 'within a private project' do
      let(:project) { private_project }

      it { is_expected.to be_allowed(:admin_issue) }
    end
  end

  describe 'change_restrict_user_defined_variables' do
    using RSpec::Parameterized::TableSyntax

    where(:user_role, :minimum_role, :allowed) do
      :guest      | :developer      | false
      :reporter   | :developer      | false
      :developer  | :developer      | false
      :maintainer | :developer      | true
      :maintainer | :maintainer     | true
      :maintainer | :no_one_allowed | true
      :owner      | :owner          | true
      :developer  | :owner          | false
      :maintainer | :owner          | false
    end

    with_them do
      let(:current_user) { public_send(user_role) }

      before do
        ci_cd_settings = project.ci_cd_settings
        ci_cd_settings.pipeline_variables_minimum_override_role = minimum_role
        ci_cd_settings.save!
      end

      it 'allows/disallows change_restrict_user_defined_variables variables based on project defined minimum role' do
        if allowed
          is_expected.to be_allowed(:change_restrict_user_defined_variables)
        else
          is_expected.to be_disallowed(:change_restrict_user_defined_variables)
        end
      end
    end
  end

  describe 'set_pipeline_variables' do
    context 'when `pipeline_variables_minimum_override_role` is defined' do
      using RSpec::Parameterized::TableSyntax

      where(:user_role, :minimum_role, :restrict_variables, :allowed) do
        :developer   | :no_one_allowed | true | false
        :maintainer  | :no_one_allowed | true | false
        :owner       | :no_one_allowed | true | false
        :guest       | :no_one_allowed | true | false
        :reporter    | :no_one_allowed | true | false
        :anonymous   | :no_one_allowed | true | false
        :developer   | :developer      | true | true
        :maintainer  | :developer      | true | true
        :owner       | :developer      | true | true
        :guest       | :developer      | true | false
        :reporter    | :developer      | true | false
        :anonymous   | :developer      | true | false
        :developer   | :maintainer     | true | false
        :maintainer  | :maintainer     | true | true
        :owner       | :maintainer     | true | true
        :guest       | :maintainer     | true | false
        :reporter    | :maintainer     | true | false
        :anonymous   | :maintainer     | true | false
        :developer   | :owner          | true | false
        :maintainer  | :owner          | true | false
        :owner       | :owner          | true | true
        :guest       | :owner          | true | false
        :reporter    | :owner          | true | false
        :anonymous   | :owner          | true | false
        :developer   | :no_one_allowed | false | true
        :maintainer  | :no_one_allowed | false | true
        :owner       | :no_one_allowed | false | true
        :guest       | :no_one_allowed | false | true
        :reporter    | :no_one_allowed | false | true
        :anonymous   | :no_one_allowed | false | true
        :developer   | :developer      | false | true
        :maintainer  | :developer      | false | true
        :owner       | :developer      | false | true
        :guest       | :developer      | false | true
        :reporter    | :developer      | false | true
        :anonymous   | :developer      | false | true
        :developer   | :maintainer     | false | true
        :maintainer  | :maintainer     | false | true
        :owner       | :maintainer     | false | true
        :guest       | :maintainer     | false | true
        :reporter    | :maintainer     | false | true
        :anonymous   | :maintainer     | false | true
        :developer   | :owner          | false | true
        :maintainer  | :owner          | false | true
        :owner       | :owner          | false | true
        :guest       | :owner          | false | true
        :reporter    | :owner          | false | true
        :anonymous   | :owner          | false | true
      end
      with_them do
        let(:current_user) { public_send(user_role) }

        before do
          ci_cd_settings = project.ci_cd_settings
          ci_cd_settings.restrict_user_defined_variables = restrict_variables
          ci_cd_settings.pipeline_variables_minimum_override_role = minimum_role
          ci_cd_settings.save!
        end

        it 'allows/disallows set pipeline variables based on project defined minimum role' do
          if allowed
            is_expected.to be_allowed(:set_pipeline_variables)
          else
            is_expected.to be_disallowed(:set_pipeline_variables)
          end
        end
      end
    end

    shared_examples 'set_pipeline_variables only on restrict_user_defined_variables' do
      context 'when user is developer' do
        let(:current_user) { developer }

        context 'when project allows user defined variables' do
          before do
            project.update!(restrict_user_defined_variables: false)
          end

          it { is_expected.to be_allowed(:set_pipeline_variables) }
        end

        context 'when project restricts use of user defined variables' do
          before do
            project.update!(restrict_user_defined_variables: true)
          end

          it { is_expected.not_to be_allowed(:set_pipeline_variables) }
        end
      end

      context 'when user is maintainer' do
        let(:current_user) { maintainer }

        context 'when project allows user defined variables' do
          before do
            project.update!(restrict_user_defined_variables: false)
          end

          it { is_expected.to be_allowed(:set_pipeline_variables) }
        end

        context 'when project restricts use of user defined variables' do
          before do
            project.update!(restrict_user_defined_variables: true)
          end

          it { is_expected.to be_allowed(:set_pipeline_variables) }
        end
      end
    end

    it_behaves_like 'set_pipeline_variables only on restrict_user_defined_variables'
  end

  context 'support bot' do
    let(:current_user) { Users::Internal.support_bot }

    context 'with service desk disabled' do
      it { expect_allowed(:public_access) }
      it { expect_disallowed(:guest_access, :create_note, :read_project) }
    end

    context 'with service desk enabled' do
      before do
        allow(project).to receive(:service_desk_enabled?).and_return(true)
      end

      it { expect_allowed(:reporter_access, :create_note, :read_issue, :read_work_item) }

      context 'when issues are protected members only' do
        before do
          project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
        end

        it { expect_allowed(:reporter_access, :create_note, :read_issue, :read_work_item) }
      end
    end
  end

  context "project bots" do
    let(:project_bot) { create(:user, :project_bot) }
    let(:user) { create(:user) }

    context "project_bot_access" do
      context "when regular user and part of the project" do
        let(:current_user) { user }

        before do
          project.add_developer(user)
        end

        it { is_expected.not_to be_allowed(:project_bot_access) }
      end

      context "when project bot and not part of the project" do
        let(:current_user) { project_bot }

        it { is_expected.not_to be_allowed(:project_bot_access) }
      end

      context "when project bot and part of the project" do
        let(:current_user) { project_bot }

        before do
          project.add_developer(project_bot)
        end

        it { is_expected.to be_allowed(:project_bot_access) }
      end
    end

    context 'with resource access tokens' do
      let(:current_user) { project_bot }

      before do
        project.add_maintainer(project_bot)
      end

      it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
    end
  end

  describe 'read_prometheus_alerts' do
    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:read_prometheus_alerts) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:read_prometheus_alerts) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_prometheus_alerts) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_prometheus_alerts) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:read_prometheus_alerts) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:read_prometheus_alerts) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_prometheus_alerts) }
    end

    context 'with anonymous' do
      let(:current_user) { anonymous }

      it { is_expected.to be_disallowed(:read_prometheus_alerts) }
    end
  end

  describe 'metrics_dashboard feature' do
    context 'public project' do
      let(:project) { public_project }

      context 'feature private' do
        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
        end
      end

      context 'feature enabled' do
        before do
          project.project_feature.update!(metrics_dashboard_access_level: ProjectFeature::ENABLED)
        end

        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_disallowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_disallowed(:create_metrics_user_starred_dashboard) }
        end
      end
    end

    context 'internal project' do
      let(:project) { internal_project }

      context 'feature private' do
        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end
      end

      context 'feature enabled' do
        before do
          project.project_feature.update!(metrics_dashboard_access_level: ProjectFeature::ENABLED)
        end

        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end
      end
    end

    context 'private project' do
      let(:project) { private_project }

      context 'feature private' do
        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end
      end

      context 'feature enabled' do
        context 'with reporter' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:metrics_dashboard) }
          it { is_expected.to be_allowed(:read_prometheus) }
          it { is_expected.to be_allowed(:read_deployment) }
          it { is_expected.to be_allowed(:read_metrics_user_starred_dashboard) }
          it { is_expected.to be_allowed(:create_metrics_user_starred_dashboard) }
        end

        context 'with guest' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end

        context 'with anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:metrics_dashboard) }
          it { is_expected.to be_disallowed(:read_prometheus) }
        end
      end
    end

    context 'feature disabled' do
      before do
        project.project_feature.update!(metrics_dashboard_access_level: ProjectFeature::DISABLED)
      end

      context 'with reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:metrics_dashboard) }
      end

      context 'with guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:metrics_dashboard) }
      end

      context 'with anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(:metrics_dashboard) }
      end
    end
  end

  context 'deploy key access' do
    context 'private project' do
      let(:project) { private_project }
      let!(:deploy_key) { create(:deploy_key, user: owner) }

      subject { described_class.new(deploy_key, project) }

      context 'when a read deploy key is enabled in the project' do
        let!(:deploy_keys_project) { create(:deploy_keys_project, project: project, deploy_key: deploy_key) }

        it { is_expected.to be_allowed(:download_code) }
        it { is_expected.to be_disallowed(:push_code) }
        it { is_expected.to be_disallowed(:read_project) }
      end

      context 'when a write deploy key is enabled in the project' do
        let!(:deploy_keys_project) { create(:deploy_keys_project, :write_access, project: project, deploy_key: deploy_key) }

        it { is_expected.to be_allowed(:download_code) }
        it { is_expected.to be_allowed(:push_code) }
        it { is_expected.to be_disallowed(:read_project) }
      end

      context 'when the deploy key is not enabled in the project' do
        it { is_expected.to be_disallowed(:download_code) }
        it { is_expected.to be_disallowed(:push_code) }
        it { is_expected.to be_disallowed(:read_project) }
      end
    end
  end

  context 'deploy token access' do
    let!(:project_deploy_token) do
      create(:project_deploy_token, project: project, deploy_token: deploy_token)
    end

    subject { described_class.new(deploy_token, project) }

    context 'private project' do
      let(:project) { private_project }

      context 'a deploy token with read_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: true, write_registry: false) }

        it { is_expected.to be_allowed(:read_container_image) }
        it { is_expected.to be_disallowed(:create_container_image) }

        context 'with registry disabled' do
          include_context 'registry disabled via project features'

          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
        end
      end

      context 'a deploy token with write_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: false, write_registry: true) }

        it { is_expected.to be_disallowed(:read_container_image) }
        it { is_expected.to be_allowed(:create_container_image) }

        context 'with registry disabled' do
          include_context 'registry disabled via project features'

          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
        end
      end

      context 'a deploy token with no registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: false, write_registry: false) }

        it { is_expected.to be_disallowed(:read_container_image) }
        it { is_expected.to be_disallowed(:create_container_image) }
      end

      context 'a deploy token with read_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_repository: false, read_registry: false, read_package_registry: true) }

        it { is_expected.to be_allowed(:read_project) }
        it { is_expected.to be_allowed(:read_package) }
        it { is_expected.to be_disallowed(:create_package) }

        it_behaves_like 'package access with repository disabled'
      end

      context 'a deploy token with write_package_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_repository: false, read_registry: false, write_package_registry: true) }

        it { is_expected.to be_allowed(:create_package) }
        it { is_expected.to be_allowed(:read_package) }
        it { is_expected.to be_allowed(:read_project) }
        it { is_expected.to be_allowed(:destroy_package) }

        it_behaves_like 'package access with repository disabled'
      end
    end

    context 'public project' do
      let(:project) { public_project }

      context 'a deploy token with read_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: true, write_registry: false) }

        it { is_expected.to be_allowed(:read_container_image) }
        it { is_expected.to be_disallowed(:create_container_image) }

        context 'with registry disabled' do
          include_context 'registry disabled via project features'

          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
        end

        context 'with registry private' do
          include_context 'registry set to private via project features'

          it { is_expected.to be_allowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
        end
      end

      context 'a deploy token with write_registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: false, write_registry: true) }

        it { is_expected.to be_allowed(:read_container_image) }
        it { is_expected.to be_allowed(:create_container_image) }

        context 'with registry disabled' do
          include_context 'registry disabled via project features'

          it { is_expected.to be_disallowed(:read_container_image) }
          it { is_expected.to be_disallowed(:create_container_image) }
        end

        context 'with registry private' do
          include_context 'registry set to private via project features'

          it { is_expected.to be_allowed(:read_container_image) }
          it { is_expected.to be_allowed(:create_container_image) }
        end
      end

      context 'a deploy token with no registry scope' do
        let(:deploy_token) { create(:deploy_token, read_registry: false, write_registry: false) }

        it { is_expected.to be_disallowed(:read_container_image) }
        it { is_expected.to be_disallowed(:create_container_image) }
      end
    end
  end

  describe 'create_web_ide_terminal' do
    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:create_web_ide_terminal) }
      end

      context 'when admin mode disabled' do
        it { is_expected.to be_disallowed(:create_web_ide_terminal) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:create_web_ide_terminal) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:create_web_ide_terminal) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:create_web_ide_terminal) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:create_web_ide_terminal) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:create_web_ide_terminal) }
    end

    context 'with non member' do
      let(:current_user) { non_member }

      it { is_expected.to be_disallowed(:create_web_ide_terminal) }
    end

    context 'with anonymous' do
      let(:current_user) { anonymous }

      it { is_expected.to be_disallowed(:create_web_ide_terminal) }
    end
  end

  describe 'read_repository_graphs' do
    let(:current_user) { guest }

    before do
      allow(subject).to receive(:allowed?).with(:read_repository_graphs).and_call_original
      allow(subject).to receive(:allowed?).with(:download_code).and_return(can_download_code)
    end

    context 'when user can download_code' do
      let(:can_download_code) { true }

      it { is_expected.to be_allowed(:read_repository_graphs) }
    end

    context 'when user cannot download_code' do
      let(:can_download_code) { false }

      it { is_expected.to be_disallowed(:read_repository_graphs) }
    end
  end

  context 'security configuration feature' do
    %w[guest reporter].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'prevents reading security configuration' do
          expect_disallowed(:read_security_configuration)
        end
      end
    end

    %w[developer maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'allows reading security configuration' do
          expect_allowed(:read_security_configuration)
        end
      end
    end
  end

  context 'infrastructure google cloud feature' do
    %w[guest reporter developer].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'disallows managing google cloud' do
          expect_disallowed(:admin_project_google_cloud)
        end
      end
    end

    %w[maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'allows managing google cloud' do
          expect_allowed(:admin_project_google_cloud)
        end
      end
    end
  end

  context 'infrastructure aws feature' do
    %w[guest reporter developer].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'disallows managing aws' do
          expect_disallowed(:admin_project_aws)
        end
      end
    end

    %w[maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it 'allows managing aws' do
          expect_allowed(:admin_project_aws)
        end
      end
    end
  end

  describe 'design permissions' do
    include DesignManagementTestHelpers

    let(:current_user) { reporter }

    let(:guest_design_abilities) { %i[read_design read_design_activity] }
    let(:reporter_design_abilities) { %i[create_design destroy_design move_design update_design] }
    let(:design_abilities) { guest_design_abilities + reporter_design_abilities }

    context 'when design management is not available' do
      before do
        enable_design_management(false)
      end

      it { is_expected.not_to be_allowed(*design_abilities) }
    end

    context 'when design management is available' do
      before do
        enable_design_management
      end

      it { is_expected.to be_allowed(*design_abilities) }

      context 'when user has below reporter access' do
        let(:current_user) { guest }

        it { is_expected.to be_allowed(*guest_design_abilities) }
        it { is_expected.not_to be_allowed(*reporter_design_abilities) }
      end
    end
  end

  describe 'read_build_report_results' do
    let(:current_user) { guest }

    before do
      allow(subject).to receive(:allowed?).with(:read_build_report_results).and_call_original
      allow(subject).to receive(:allowed?).with(:read_build).and_return(can_read_build)
      allow(subject).to receive(:allowed?).with(:read_pipeline).and_return(can_read_pipeline)
    end

    context 'when user can read_build and read_pipeline' do
      let(:can_read_build) { true }
      let(:can_read_pipeline) { true }

      it { is_expected.to be_allowed(:read_build_report_results) }
    end

    context 'when user can read_build but cannot read_pipeline' do
      let(:can_read_build) { true }
      let(:can_read_pipeline) { false }

      it { is_expected.to be_disallowed(:read_build_report_results) }
    end

    context 'when user cannot read_build but can read_pipeline' do
      let(:can_read_build) { false }
      let(:can_read_pipeline) { true }

      it { is_expected.to be_disallowed(:read_build_report_results) }
    end

    context 'when user cannot read_build and cannot read_pipeline' do
      let(:can_read_build) { false }
      let(:can_read_pipeline) { false }

      it { is_expected.to be_disallowed(:read_build_report_results) }
    end
  end

  describe 'read_package' do
    context 'with admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_package) }

      it_behaves_like 'package access with repository disabled'
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with non member' do
      let(:current_user) { non_member }

      it { is_expected.to be_allowed(:read_package) }
    end

    context 'with anonymous' do
      let(:current_user) { anonymous }

      it { is_expected.to be_allowed(:read_package) }
    end
  end

  describe 'admin_package' do
    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:admin_package) }
      end

      context 'when admin mode disabled' do
        it { is_expected.to be_disallowed(:admin_package) }
      end
    end

    %i[owner maintainer].each do |role|
      context "with #{role}" do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:admin_package) }
      end
    end

    %i[developer reporter guest non_member anonymous].each do |role|
      context "with #{role}" do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_disallowed(:admin_package) }
      end
    end
  end

  describe 'view_package_registry_project_settings' do
    context 'with packages disabled and' do
      before do
        stub_config(packages: { enabled: false })
      end

      context 'with registry enabled' do
        before do
          stub_config(registry: { enabled: true })
        end

        context 'with an admin user' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:view_package_registry_project_settings) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end

        %i[owner maintainer].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:view_package_registry_project_settings) }
          end
        end

        %i[developer reporter guest non_member anonymous].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end
      end

      context 'with registry disabled' do
        before do
          stub_config(registry: { enabled: false })
        end

        context 'with admin user' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end

        %i[owner maintainer developer reporter guest non_member anonymous].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end
      end
    end

    context 'with registry disabled and' do
      before do
        stub_config(registry: { enabled: false })
      end

      context 'with packages enabled' do
        before do
          stub_config(packages: { enabled: true })
        end

        context 'with an admin user' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:view_package_registry_project_settings) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end

        %i[owner maintainer].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:view_package_registry_project_settings) }
          end
        end

        %i[developer reporter guest non_member anonymous].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end
      end

      context 'with packages disabled' do
        before do
          stub_config(packages: { enabled: false })
        end

        context 'with admin user' do
          let(:current_user) { admin }

          context 'when admin mode enabled', :enable_admin_mode do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end

          context 'when admin mode disabled' do
            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end

        %i[owner maintainer developer reporter guest non_member anonymous].each do |role|
          context "with #{role}" do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
          end
        end
      end
    end

    context 'with registry & packages both disabled' do
      before do
        stub_config(registry: { enabled: false })
        stub_config(packages: { enabled: false })
      end

      context 'with admin user' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
        end
      end

      %i[owner maintainer developer reporter guest non_member anonymous].each do |role|
        context "with #{role}" do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:view_package_registry_project_settings) }
        end
      end
    end
  end

  describe 'read_feature_flag' do
    subject { described_class.new(current_user, project) }

    context 'with maintainer' do
      let(:current_user) { maintainer }

      context 'when repository is available' do
        it { is_expected.to be_allowed(:read_feature_flag) }
      end

      context 'when repository is disabled' do
        before do
          project.project_feature.update!(
            merge_requests_access_level: ProjectFeature::DISABLED,
            builds_access_level: ProjectFeature::DISABLED,
            repository_access_level: ProjectFeature::DISABLED
          )
        end

        it { is_expected.to be_disallowed(:read_feature_flag) }
      end
    end

    context 'with developer' do
      let(:current_user) { developer }

      context 'when repository is available' do
        it { is_expected.to be_allowed(:read_feature_flag) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      context 'when repository is available' do
        it { is_expected.to be_disallowed(:read_feature_flag) }
      end
    end
  end

  describe 'read_analytics' do
    context 'anonymous user' do
      let(:current_user) { anonymous }

      it { is_expected.to be_allowed(:read_analytics) }
    end

    context 'with various analytics features' do
      let_it_be(:project_with_analytics_disabled) { create(:project, :analytics_disabled) }
      let_it_be(:project_with_analytics_private) { create(:project, :analytics_private) }
      let_it_be(:project_with_analytics_enabled) { create(:project, :analytics_enabled) }

      before_all do
        project_with_analytics_disabled.add_guest(guest)
        project_with_analytics_private.add_guest(guest)
        project_with_analytics_enabled.add_guest(guest)

        project_with_analytics_disabled.add_reporter(reporter)
        project_with_analytics_private.add_reporter(reporter)
        project_with_analytics_enabled.add_reporter(reporter)

        project_with_analytics_disabled.add_developer(developer)
        project_with_analytics_private.add_developer(developer)
        project_with_analytics_enabled.add_developer(developer)
      end

      context 'when analytics is disabled for the project' do
        let(:project) { project_with_analytics_disabled }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_disallowed(:read_cycle_analytics) }
          it { is_expected.to be_disallowed(:read_insights) }
          it { is_expected.to be_disallowed(:read_repository_graphs) }
          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end

        context 'for reporter user' do
          let(:current_user) { reporter }

          it { is_expected.to be_disallowed(:read_cycle_analytics) }
          it { is_expected.to be_disallowed(:read_insights) }
          it { is_expected.to be_disallowed(:read_repository_graphs) }
          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_disallowed(:read_cycle_analytics) }
          it { is_expected.to be_disallowed(:read_insights) }
          it { is_expected.to be_disallowed(:read_repository_graphs) }
          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end
      end

      context 'when analytics is private for the project' do
        let(:project) { project_with_analytics_private }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_disallowed(:read_repository_graphs) }
          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end

        context 'for reporter user' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_allowed(:read_repository_graphs) }
          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_allowed(:read_repository_graphs) }
          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end
      end

      context 'when analytics is enabled for the project' do
        let(:project) { project_with_analytics_enabled }

        context 'for guest user' do
          let(:current_user) { guest }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_disallowed(:read_repository_graphs) }
          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end

        context 'for reporter user' do
          let(:current_user) { reporter }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_allowed(:read_repository_graphs) }
          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end

        context 'for developer' do
          let(:current_user) { developer }

          it { is_expected.to be_allowed(:read_cycle_analytics) }
          it { is_expected.to be_allowed(:read_insights) }
          it { is_expected.to be_allowed(:read_repository_graphs) }
          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end
      end
    end

    context 'project member' do
      let(:project) { private_project }

      %w[guest reporter developer maintainer].each do |role|
        context role do
          let(:current_user) { send(role) }

          it { is_expected.to be_allowed(:read_analytics) }

          context "without access to Analytics" do
            before do
              project.project_feature.update!(analytics_access_level: ProjectFeature::DISABLED)
            end

            it { is_expected.to be_disallowed(:read_analytics) }
          end
        end
      end
    end
  end

  describe 'read_ci_cd_analytics' do
    context 'public project' do
      let(:project) { create(:project, :public, :analytics_enabled) }
      let(:current_user) { create(:user) }

      context 'when public pipelines are disabled for the project' do
        before do
          project.update!(public_builds: false)
        end

        context 'project member' do
          %w[guest reporter developer maintainer].each do |role|
            context role do
              before do
                project.add_member(current_user, role.to_sym)
              end

              if role == 'guest'
                it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
              else
                it { is_expected.to be_allowed(:read_ci_cd_analytics) }
              end
            end
          end
        end

        context 'non member' do
          let(:current_user) { non_member }

          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end

        context 'anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
        end
      end

      context 'when public pipelines are enabled for the project' do
        before do
          project.update!(public_builds: true)
        end

        context 'project member' do
          %w[guest reporter developer maintainer].each do |role|
            context role do
              before do
                project.add_member(current_user, role.to_sym)
              end

              it { is_expected.to be_allowed(:read_ci_cd_analytics) }
            end
          end
        end

        context 'non member' do
          let(:current_user) { non_member }

          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end

        context 'anonymous' do
          let(:current_user) { anonymous }

          it { is_expected.to be_allowed(:read_ci_cd_analytics) }
        end
      end
    end

    context 'private project' do
      let(:project) { create(:project, :private, :analytics_enabled) }
      let(:current_user) { create(:user) }

      context 'project member' do
        %w[guest reporter developer maintainer].each do |role|
          context role do
            before do
              project.add_member(current_user, role.to_sym)
            end

            if role == 'guest'
              it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
            else
              it { is_expected.to be_allowed(:read_ci_cd_analytics) }
            end
          end
        end
      end

      context 'non member' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
      end

      context 'anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(:read_ci_cd_analytics) }
      end
    end
  end

  it_behaves_like 'Self-managed Core resource access tokens'

  describe 'environments feature' do
    using RSpec::Parameterized::TableSyntax

    let(:guest_permissions) { [:read_environment, :read_deployment] }

    let(:developer_permissions) do
      guest_permissions + [
        :create_environment, :create_deployment, :update_environment, :update_deployment, :destroy_environment
      ]
    end

    let(:maintainer_permissions) do
      developer_permissions + [:admin_environment, :admin_deployment]
    end

    where(:project_visibility, :access_level, :role, :allowed) do
      :public   | ProjectFeature::ENABLED   | :maintainer | true
      :public   | ProjectFeature::ENABLED   | :developer  | true
      :public   | ProjectFeature::ENABLED   | :guest      | true
      :public   | ProjectFeature::ENABLED   | :anonymous  | true
      :public   | ProjectFeature::PRIVATE   | :maintainer | true
      :public   | ProjectFeature::PRIVATE   | :developer  | true
      :public   | ProjectFeature::PRIVATE   | :guest      | false
      :public   | ProjectFeature::PRIVATE   | :anonymous  | false
      :public   | ProjectFeature::DISABLED  | :maintainer | false
      :public   | ProjectFeature::DISABLED  | :developer  | false
      :public   | ProjectFeature::DISABLED  | :guest      | false
      :public   | ProjectFeature::DISABLED  | :anonymous  | false
      :internal | ProjectFeature::ENABLED   | :maintainer | true
      :internal | ProjectFeature::ENABLED   | :developer  | true
      :internal | ProjectFeature::ENABLED   | :guest      | true
      :internal | ProjectFeature::ENABLED   | :anonymous  | false
      :internal | ProjectFeature::PRIVATE   | :maintainer | true
      :internal | ProjectFeature::PRIVATE   | :developer  | true
      :internal | ProjectFeature::PRIVATE   | :guest      | false
      :internal | ProjectFeature::PRIVATE   | :anonymous  | false
      :internal | ProjectFeature::DISABLED  | :maintainer | false
      :internal | ProjectFeature::DISABLED  | :developer  | false
      :internal | ProjectFeature::DISABLED  | :guest      | false
      :internal | ProjectFeature::DISABLED  | :anonymous  | false
      :private  | ProjectFeature::ENABLED   | :maintainer | true
      :private  | ProjectFeature::ENABLED   | :developer  | true
      :private  | ProjectFeature::ENABLED   | :guest      | false
      :private  | ProjectFeature::ENABLED   | :anonymous  | false
      :private  | ProjectFeature::PRIVATE   | :maintainer | true
      :private  | ProjectFeature::PRIVATE   | :developer  | true
      :private  | ProjectFeature::PRIVATE   | :guest      | false
      :private  | ProjectFeature::PRIVATE   | :anonymous  | false
      :private  | ProjectFeature::DISABLED  | :maintainer | false
      :private  | ProjectFeature::DISABLED  | :developer  | false
      :private  | ProjectFeature::DISABLED  | :guest      | false
      :private  | ProjectFeature::DISABLED  | :anonymous  | false
    end

    with_them do
      let(:current_user) { user_subject(role) }
      let(:project) { project_subject(project_visibility) }

      it 'allows/disallows the abilities based on the environments feature access level' do
        project.project_feature.update!(environments_access_level: access_level)

        if allowed
          expect_allowed(*permissions_abilities(role))
        else
          expect_disallowed(*permissions_abilities(role))
        end
      end
    end
  end

  describe 'monitor feature' do
    using RSpec::Parameterized::TableSyntax

    let(:guest_permissions) { [] }

    let(:developer_permissions) do
      guest_permissions + [
        :read_sentry_issue, :read_alert_management_alert, :metrics_dashboard,
        :update_sentry_issue, :update_alert_management_alert
      ]
    end

    let(:maintainer_permissions) { developer_permissions }

    where(:project_visibility, :access_level, :role, :allowed) do
      :public   | ProjectFeature::ENABLED   | :maintainer | true
      :public   | ProjectFeature::ENABLED   | :developer  | true
      :public   | ProjectFeature::ENABLED   | :guest      | true
      :public   | ProjectFeature::ENABLED   | :anonymous  | true
      :public   | ProjectFeature::PRIVATE   | :maintainer | true
      :public   | ProjectFeature::PRIVATE   | :developer  | true
      :public   | ProjectFeature::PRIVATE   | :guest      | true
      :public   | ProjectFeature::PRIVATE   | :anonymous  | false
      :public   | ProjectFeature::DISABLED  | :maintainer | false
      :public   | ProjectFeature::DISABLED  | :developer  | false
      :public   | ProjectFeature::DISABLED  | :guest      | false
      :public   | ProjectFeature::DISABLED  | :anonymous  | false
      :internal | ProjectFeature::ENABLED   | :maintainer | true
      :internal | ProjectFeature::ENABLED   | :developer  | true
      :internal | ProjectFeature::ENABLED   | :guest      | true
      :internal | ProjectFeature::ENABLED   | :anonymous  | false
      :internal | ProjectFeature::PRIVATE   | :maintainer | true
      :internal | ProjectFeature::PRIVATE   | :developer  | true
      :internal | ProjectFeature::PRIVATE   | :guest      | true
      :internal | ProjectFeature::PRIVATE   | :anonymous  | false
      :internal | ProjectFeature::DISABLED  | :maintainer | false
      :internal | ProjectFeature::DISABLED  | :developer  | false
      :internal | ProjectFeature::DISABLED  | :guest      | false
      :internal | ProjectFeature::DISABLED  | :anonymous  | false
      :private  | ProjectFeature::ENABLED   | :maintainer | true
      :private  | ProjectFeature::ENABLED   | :developer  | true
      :private  | ProjectFeature::ENABLED   | :guest      | false
      :private  | ProjectFeature::ENABLED   | :anonymous  | false
      :private  | ProjectFeature::PRIVATE   | :maintainer | true
      :private  | ProjectFeature::PRIVATE   | :developer  | true
      :private  | ProjectFeature::PRIVATE   | :guest      | false
      :private  | ProjectFeature::PRIVATE   | :anonymous  | false
      :private  | ProjectFeature::DISABLED  | :maintainer | false
      :private  | ProjectFeature::DISABLED  | :developer  | false
      :private  | ProjectFeature::DISABLED  | :guest      | false
      :private  | ProjectFeature::DISABLED  | :anonymous  | false
    end

    with_them do
      let(:current_user) { user_subject(role) }
      let(:project) { project_subject(project_visibility) }

      it 'allows/disallows the abilities based on the monitor feature access level' do
        project.project_feature.update!(monitor_access_level: access_level)

        if allowed
          expect_allowed(*permissions_abilities(role))
        else
          expect_disallowed(*permissions_abilities(role))
        end
      end
    end
  end

  describe 'feature flags feature' do
    using RSpec::Parameterized::TableSyntax

    let(:guest_permissions) { [] }

    let(:developer_permissions) do
      guest_permissions + [
        :read_feature_flag, :create_feature_flag, :update_feature_flag, :destroy_feature_flag, :admin_feature_flag,
        :admin_feature_flags_user_lists
      ]
    end

    let(:maintainer_permissions) do
      developer_permissions + [:admin_feature_flags_client]
    end

    where(:project_visibility, :access_level, :role, :allowed) do
      :public   | ProjectFeature::ENABLED   | :maintainer | true
      :public   | ProjectFeature::ENABLED   | :developer  | true
      :public   | ProjectFeature::ENABLED   | :guest      | true
      :public   | ProjectFeature::ENABLED   | :anonymous  | true
      :public   | ProjectFeature::PRIVATE   | :maintainer | true
      :public   | ProjectFeature::PRIVATE   | :developer  | true
      :public   | ProjectFeature::PRIVATE   | :guest      | true
      :public   | ProjectFeature::PRIVATE   | :anonymous  | false
      :public   | ProjectFeature::DISABLED  | :maintainer | false
      :public   | ProjectFeature::DISABLED  | :developer  | false
      :public   | ProjectFeature::DISABLED  | :guest      | false
      :public   | ProjectFeature::DISABLED  | :anonymous  | false
      :internal | ProjectFeature::ENABLED   | :maintainer | true
      :internal | ProjectFeature::ENABLED   | :developer  | true
      :internal | ProjectFeature::ENABLED   | :guest      | true
      :internal | ProjectFeature::ENABLED   | :anonymous  | false
      :internal | ProjectFeature::PRIVATE   | :maintainer | true
      :internal | ProjectFeature::PRIVATE   | :developer  | true
      :internal | ProjectFeature::PRIVATE   | :guest      | true
      :internal | ProjectFeature::PRIVATE   | :anonymous  | false
      :internal | ProjectFeature::DISABLED  | :maintainer | false
      :internal | ProjectFeature::DISABLED  | :developer  | false
      :internal | ProjectFeature::DISABLED  | :guest      | false
      :internal | ProjectFeature::DISABLED  | :anonymous  | false
      :private  | ProjectFeature::ENABLED   | :maintainer | true
      :private  | ProjectFeature::ENABLED   | :developer  | true
      :private  | ProjectFeature::ENABLED   | :guest      | false
      :private  | ProjectFeature::ENABLED   | :anonymous  | false
      :private  | ProjectFeature::PRIVATE   | :maintainer | true
      :private  | ProjectFeature::PRIVATE   | :developer  | true
      :private  | ProjectFeature::PRIVATE   | :guest      | false
      :private  | ProjectFeature::PRIVATE   | :anonymous  | false
      :private  | ProjectFeature::DISABLED  | :maintainer | false
      :private  | ProjectFeature::DISABLED  | :developer  | false
      :private  | ProjectFeature::DISABLED  | :guest      | false
      :private  | ProjectFeature::DISABLED  | :anonymous  | false
    end

    with_them do
      let(:current_user) { user_subject(role) }
      let(:project) { project_subject(project_visibility) }

      it 'allows/disallows the abilities based on the feature flags access level' do
        project.project_feature.update!(feature_flags_access_level: access_level)

        if allowed
          expect_allowed(*permissions_abilities(role))
        else
          expect_disallowed(*permissions_abilities(role))
        end
      end
    end
  end

  describe 'Releases feature' do
    using RSpec::Parameterized::TableSyntax

    let(:guest_permissions) { [:read_release] }

    let(:developer_permissions) do
      guest_permissions + [:create_release, :update_release, :destroy_release]
    end

    let(:maintainer_permissions) do
      developer_permissions
    end

    where(:project_visibility, :access_level, :role, :allowed) do
      :public   | ProjectFeature::ENABLED   | :maintainer | true
      :public   | ProjectFeature::ENABLED   | :developer  | true
      :public   | ProjectFeature::ENABLED   | :guest      | true
      :public   | ProjectFeature::ENABLED   | :anonymous  | true
      :public   | ProjectFeature::PRIVATE   | :maintainer | true
      :public   | ProjectFeature::PRIVATE   | :developer  | true
      :public   | ProjectFeature::PRIVATE   | :guest      | true
      :public   | ProjectFeature::PRIVATE   | :anonymous  | false
      :public   | ProjectFeature::DISABLED  | :maintainer | false
      :public   | ProjectFeature::DISABLED  | :developer  | false
      :public   | ProjectFeature::DISABLED  | :guest      | false
      :public   | ProjectFeature::DISABLED  | :anonymous  | false
      :internal | ProjectFeature::ENABLED   | :maintainer | true
      :internal | ProjectFeature::ENABLED   | :developer  | true
      :internal | ProjectFeature::ENABLED   | :guest      | true
      :internal | ProjectFeature::ENABLED   | :anonymous  | false
      :internal | ProjectFeature::PRIVATE   | :maintainer | true
      :internal | ProjectFeature::PRIVATE   | :developer  | true
      :internal | ProjectFeature::PRIVATE   | :guest      | true
      :internal | ProjectFeature::PRIVATE   | :anonymous  | false
      :internal | ProjectFeature::DISABLED  | :maintainer | false
      :internal | ProjectFeature::DISABLED  | :developer  | false
      :internal | ProjectFeature::DISABLED  | :guest      | false
      :internal | ProjectFeature::DISABLED  | :anonymous  | false
      :private  | ProjectFeature::ENABLED   | :maintainer | true
      :private  | ProjectFeature::ENABLED   | :developer  | true
      :private  | ProjectFeature::ENABLED   | :guest      | true
      :private  | ProjectFeature::ENABLED   | :anonymous  | false
      :private  | ProjectFeature::PRIVATE   | :maintainer | true
      :private  | ProjectFeature::PRIVATE   | :developer  | true
      :private  | ProjectFeature::PRIVATE   | :guest      | true
      :private  | ProjectFeature::PRIVATE   | :anonymous  | false
      :private  | ProjectFeature::DISABLED  | :maintainer | false
      :private  | ProjectFeature::DISABLED  | :developer  | false
      :private  | ProjectFeature::DISABLED  | :guest      | false
      :private  | ProjectFeature::DISABLED  | :anonymous  | false
    end

    with_them do
      let(:current_user) { user_subject(role) }
      let(:project) { project_subject(project_visibility) }

      it 'allows/disallows the abilities based on the Releases access level' do
        project.project_feature.update!(releases_access_level: access_level)

        if allowed
          expect_allowed(*permissions_abilities(role))
        else
          expect_disallowed(*permissions_abilities(role))
        end
      end
    end
  end

  describe 'infrastructure feature' do
    using RSpec::Parameterized::TableSyntax

    before do
      # assuming the default setting terraform_state.enabled=true
      # the terraform_state permissions should follow the same logic as the other features
      stub_config(terraform_state: { enabled: true })
    end

    let(:guest_permissions) { [] }

    let(:developer_permissions) do
      guest_permissions + [:read_terraform_state, :read_pod_logs, :read_prometheus]
    end

    let(:maintainer_permissions) do
      developer_permissions + [:create_cluster, :read_cluster, :update_cluster, :admin_cluster, :admin_terraform_state, :admin_project_google_cloud]
    end

    shared_context 'with permission matrix' do
      where(:project_visibility, :access_level, :role, :allowed) do
        :public   | ProjectFeature::ENABLED   | :maintainer | true
        :public   | ProjectFeature::ENABLED   | :developer  | true
        :public   | ProjectFeature::ENABLED   | :guest      | true
        :public   | ProjectFeature::ENABLED   | :anonymous  | true
        :public   | ProjectFeature::PRIVATE   | :maintainer | true
        :public   | ProjectFeature::PRIVATE   | :developer  | true
        :public   | ProjectFeature::PRIVATE   | :guest      | true
        :public   | ProjectFeature::PRIVATE   | :anonymous  | false
        :public   | ProjectFeature::DISABLED  | :maintainer | false
        :public   | ProjectFeature::DISABLED  | :developer  | false
        :public   | ProjectFeature::DISABLED  | :guest      | false
        :public   | ProjectFeature::DISABLED  | :anonymous  | false
        :internal | ProjectFeature::ENABLED   | :maintainer | true
        :internal | ProjectFeature::ENABLED   | :developer  | true
        :internal | ProjectFeature::ENABLED   | :guest      | true
        :internal | ProjectFeature::ENABLED   | :anonymous  | false
        :internal | ProjectFeature::PRIVATE   | :maintainer | true
        :internal | ProjectFeature::PRIVATE   | :developer  | true
        :internal | ProjectFeature::PRIVATE   | :guest      | true
        :internal | ProjectFeature::PRIVATE   | :anonymous  | false
        :internal | ProjectFeature::DISABLED  | :maintainer | false
        :internal | ProjectFeature::DISABLED  | :developer  | false
        :internal | ProjectFeature::DISABLED  | :guest      | false
        :internal | ProjectFeature::DISABLED  | :anonymous  | false
        :private  | ProjectFeature::ENABLED   | :maintainer | true
        :private  | ProjectFeature::ENABLED   | :developer  | true
        :private  | ProjectFeature::ENABLED   | :guest      | true
        :private  | ProjectFeature::ENABLED   | :anonymous  | false
        :private  | ProjectFeature::PRIVATE   | :maintainer | true
        :private  | ProjectFeature::PRIVATE   | :developer  | true
        :private  | ProjectFeature::PRIVATE   | :guest      | true
        :private  | ProjectFeature::PRIVATE   | :anonymous  | false
        :private  | ProjectFeature::DISABLED  | :maintainer | false
        :private  | ProjectFeature::DISABLED  | :developer  | false
        :private  | ProjectFeature::DISABLED  | :guest      | false
        :private  | ProjectFeature::DISABLED  | :anonymous  | false
      end
    end

    include_context 'with permission matrix'

    with_them do
      let(:current_user) { user_subject(role) }
      let(:project) { project_subject(project_visibility) }

      it 'allows/disallows the abilities based on the infrastructure access level' do
        project.project_feature.update!(infrastructure_access_level: access_level)

        if allowed
          expect_allowed(*permissions_abilities(role))
        else
          expect_disallowed(*permissions_abilities(role))
        end
      end
    end

    context 'when terraform state management is disabled' do
      include_context 'with permission matrix'

      before do
        stub_config(terraform_state: { enabled: false })
      end

      with_them do
        let(:current_user) { user_subject(role) }
        let(:project) { project_subject(project_visibility) }

        let(:developer_permissions) do
          [:read_terraform_state]
        end

        let(:maintainer_permissions) do
          developer_permissions + [:admin_terraform_state]
        end

        it 'always disallows the terraform_state feature' do
          project.project_feature.update!(infrastructure_access_level: access_level)

          expect_disallowed(*permissions_abilities(role))
        end
      end
    end
  end

  describe 'access_security_and_compliance' do
    context 'when the "Security and Compliance" is enabled' do
      before do
        project.project_feature.update!(security_and_compliance_access_level: Featurable::PRIVATE)
      end

      %w[owner maintainer developer].each do |role|
        context "when the role is #{role}" do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:access_security_and_compliance) }
        end
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:access_security_and_compliance) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:access_security_and_compliance) }
        end
      end

      %w[reporter guest].each do |role|
        context "when the role is #{role}" do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:access_security_and_compliance) }
        end
      end

      context 'with non member' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
      end

      context 'with anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
      end
    end

    context 'when the "Security and Compliance" is not enabled' do
      before do
        project.project_feature.update!(security_and_compliance_access_level: Featurable::DISABLED)
      end

      %w[owner maintainer developer reporter guest].each do |role|
        context "when the role is #{role}" do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:access_security_and_compliance) }
        end
      end

      context 'with admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_disallowed(:access_security_and_compliance) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:access_security_and_compliance) }
        end
      end

      context 'with non member' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
      end

      context 'with anonymous' do
        let(:current_user) { anonymous }

        it { is_expected.to be_disallowed(:access_security_and_compliance) }
      end
    end
  end

  describe 'when user is authenticated via CI_JOB_TOKEN', :request_store do
    using RSpec::Parameterized::TableSyntax

    RSpec.shared_examples 'CI_JOB_TOKEN enforces the expected permissions' do
      with_them do
        let(:current_user) { public_send(user_role) }
        let(:project) { public_project }
        let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }

        let(:scope_project) do
          if scope_project_type == :same
            project
          else
            create(:project, :private)
          end
        end

        before do
          current_user.set_ci_job_token_scope!(job)
          current_user.external = external_user
          project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
          scope_project.update!(
            ci_outbound_job_token_scope_enabled: token_scope_enabled,
            ci_inbound_job_token_scope_enabled: token_scope_enabled
          )
        end

        it "enforces the expected permissions" do
          if result
            is_expected.to be_allowed("#{user_role}_access".to_sym)
          else
            is_expected.to be_disallowed("#{user_role}_access".to_sym)
          end
        end
      end
    end

    where(:user_role, :external_user, :scope_project_type, :token_scope_enabled, :result) do
      :reporter | false | :same      | true  | true
      :reporter | true  | :same      | true  | true
      :reporter | false | :same      | false | true
      :reporter | false | :different | true  | false
      :reporter | true  | :different | true  | false
      :reporter | false | :different | false | true
      :guest    | false | :same      | true  | true
      :guest    | true  | :same      | true  | true
      :guest    | false | :same      | false | true
      :guest    | false | :different | true  | false
      :guest    | true  | :different | true  | false
      :guest    | false | :different | false | true
    end

    include_examples "CI_JOB_TOKEN enforces the expected permissions"

    context "when the project is public or internal and not on the allowlist" do
      where(:feature, :permissions) do
        :container_registry | [:build_read_container_image, :read_container_image]
        :package_registry   | [:read_package, :read_project]
        :builds             | [:read_commit_status]
        :releases           | [:read_release]
        :environments       | [:read_environment]
      end

      with_them do
        let(:current_user) { developer }
        let(:project) { public_project }
        let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }
        let_it_be(:scope_project) { create(:project, :private) }

        before do
          current_user.set_ci_job_token_scope!(job)

          scope_project.update!(ci_inbound_job_token_scope_enabled: true)
        end

        it 'allows the permissions based on the feature access level' do
          project.project_feature.update!("#{feature}_access_level": ProjectFeature::ENABLED)

          permissions.each { |p| expect_allowed(p) }
        end

        it 'disallows the permissions if feature access level is restricted' do
          project.project_feature.update!("#{feature}_access_level": ProjectFeature::PRIVATE)

          permissions.each { |p| expect_disallowed(p) }
        end

        it 'disallows the permissions if feature access level is disabled' do
          project.project_feature.update!("#{feature}_access_level": ProjectFeature::DISABLED)

          permissions.each { |p| expect_disallowed(p) }
        end
      end
    end
  end

  describe 'public_user_access for internal project' do
    using RSpec::Parameterized::TableSyntax

    let(:policy) { :public_user_access }

    where(:project_visibility, :external_user, :token_scope_enabled, :role, :allowed) do
      :private  | false | false | :anonymous | false
      :private  | false | false | :guest     | true
      :private  | false | false | :reporter  | true
      :private  | false | false | :developer | true
      :private  | false | false | :maintainer | true
      :private  | false | false | :owner | true
      :public   | false | false | :anonymous | false
      :public   | false | false | :guest     | true
      :public   | false | false | :reporter  | true
      :public   | false | false | :developer | true
      :public   | false | false | :maintainer | true
      :public   | false | false | :owner | true
      :internal | false | false | :anonymous | false
      :internal | false | false | :guest     | true
      :internal | false | false | :reporter  | true
      :internal | false | false | :developer | true
      :internal | false | false | :maintainer | true
      :internal | false | false | :owner | true
      :private  | true | false | :anonymous | false
      :private  | true | false | :guest     | false
      :private  | true | false | :reporter  | false
      :private  | true | false | :developer | false
      :private  | true | false | :maintainer | false
      :private  | true | false | :owner | false
      :public   | true | false | :anonymous | false
      :public   | true | false | :guest     | false
      :public   | true | false | :reporter  | false
      :public   | true | false | :developer | false
      :public   | true | false | :maintainer | false
      :public   | true | false | :owner | false
      :internal | true | false | :anonymous | false
      :internal | true | false | :guest     | false
      :internal | true | false | :reporter  | false
      :internal | true | false | :developer | false
      :internal | true | false | :maintainer | false
      :internal | true | false | :owner | false
      :private  | false | true | :anonymous | false
      :private  | false | true | :guest     | true
      :private  | false | true | :reporter  | true
      :private  | false | true | :developer | true
      :private  | false | true | :maintainer | true
      :private  | false | true | :owner | true
      :public   | false | true | :anonymous | false
      :public   | false | true | :guest     | true
      :public   | false | true | :reporter  | true
      :public   | false | true | :developer | true
      :public   | false | true | :maintainer | true
      :public   | false | true | :owner | true
      :internal | false | true | :anonymous | false
      :internal | false | true | :guest     | true
      :internal | false | true | :reporter  | true
      :internal | false | true | :developer | true
      :internal | false | true | :maintainer | true
      :internal | false | true | :owner | true
      :private  | true | true | :anonymous | false
      :private  | true | true | :guest     | false
      :private  | true | true | :reporter  | false
      :private  | true | true | :developer | false
      :private  | true | true | :maintainer | false
      :private  | true | true | :owner | false
      :public   | true | true | :anonymous | false
      :public   | true | true | :guest     | false
      :public   | true | true | :reporter  | false
      :public   | true | true | :developer | false
      :public   | true | true | :maintainer | false
      :public   | true | true | :owner | false
      :internal | true | true | :anonymous | false
      :internal | true | true | :guest     | false
      :internal | true | true | :reporter  | false
      :internal | true | true | :developer | false
      :internal | true | true | :maintainer | false
      :internal | true | true | :owner | false
    end

    with_them do
      let(:current_user) do
        if role == :anonymous
          anonymous
        else
          public_send(role)
        end
      end

      let(:project) { create(:project, :internal, ci_inbound_job_token_scope_enabled: token_scope_enabled) }
      let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }
      let(:scope_project) { public_send("#{project_visibility}_project") }

      before do
        if role != :anonymous
          # The below two allow statements are to make sure the CI_JOB_TOKEN is used to access the project and the internal project is not in scope
          allow(current_user).to receive(:ci_job_token_scope).and_return(current_user.set_ci_job_token_scope!(job))
          allow(Ci::JobToken::Scope).to receive(:accessible?).with(project).and_return(false)
          current_user.external = external_user
        end
      end

      it "enforces the expected permissions" do
        if allowed
          is_expected.to be_allowed(policy)
        else
          is_expected.to be_disallowed(policy)
        end
      end
    end
  end

  describe 'container_image policies' do
    using RSpec::Parameterized::TableSyntax

    # These are permissions that admins should not have when the project is private
    # or the container registry is private.
    let(:admin_excluded_permissions) { [:build_read_container_image] }

    let(:anonymous_operations_permissions) { [:read_container_image] }
    let(:guest_operations_permissions) { anonymous_operations_permissions + [:build_read_container_image] }

    let(:developer_operations_permissions) do
      guest_operations_permissions + [
        :create_container_image, :update_container_image, :destroy_container_image
      ]
    end

    let(:maintainer_operations_permissions) do
      developer_operations_permissions + [
        :admin_container_image
      ]
    end

    let(:all_permissions) { maintainer_operations_permissions }

    where(:project_visibility, :access_level, :role, :allowed) do
      :public   | ProjectFeature::ENABLED   | :admin      | true
      :public   | ProjectFeature::ENABLED   | :owner      | true
      :public   | ProjectFeature::ENABLED   | :maintainer | true
      :public   | ProjectFeature::ENABLED   | :developer  | true
      :public   | ProjectFeature::ENABLED   | :reporter   | true
      :public   | ProjectFeature::ENABLED   | :guest      | true
      :public   | ProjectFeature::ENABLED   | :anonymous  | true
      :public   | ProjectFeature::PRIVATE   | :admin      | true
      :public   | ProjectFeature::PRIVATE   | :owner      | true
      :public   | ProjectFeature::PRIVATE   | :maintainer | true
      :public   | ProjectFeature::PRIVATE   | :developer  | true
      :public   | ProjectFeature::PRIVATE   | :reporter   | true
      :public   | ProjectFeature::PRIVATE   | :guest      | false
      :public   | ProjectFeature::PRIVATE   | :anonymous  | false
      :public   | ProjectFeature::DISABLED  | :admin      | false
      :public   | ProjectFeature::DISABLED  | :owner      | false
      :public   | ProjectFeature::DISABLED  | :maintainer | false
      :public   | ProjectFeature::DISABLED  | :developer  | false
      :public   | ProjectFeature::DISABLED  | :reporter   | false
      :public   | ProjectFeature::DISABLED  | :guest      | false
      :public   | ProjectFeature::DISABLED  | :anonymous  | false
      :internal | ProjectFeature::ENABLED   | :admin      | true
      :internal | ProjectFeature::ENABLED   | :owner      | true
      :internal | ProjectFeature::ENABLED   | :maintainer | true
      :internal | ProjectFeature::ENABLED   | :developer  | true
      :internal | ProjectFeature::ENABLED   | :reporter   | true
      :internal | ProjectFeature::ENABLED   | :guest      | true
      :internal | ProjectFeature::ENABLED   | :anonymous  | false
      :internal | ProjectFeature::PRIVATE   | :admin      | true
      :internal | ProjectFeature::PRIVATE   | :owner      | true
      :internal | ProjectFeature::PRIVATE   | :maintainer | true
      :internal | ProjectFeature::PRIVATE   | :developer  | true
      :internal | ProjectFeature::PRIVATE   | :reporter   | true
      :internal | ProjectFeature::PRIVATE   | :guest      | false
      :internal | ProjectFeature::PRIVATE   | :anonymous  | false
      :internal | ProjectFeature::DISABLED  | :admin      | false
      :internal | ProjectFeature::DISABLED  | :owner      | false
      :internal | ProjectFeature::DISABLED  | :maintainer | false
      :internal | ProjectFeature::DISABLED  | :developer  | false
      :internal | ProjectFeature::DISABLED  | :reporter   | false
      :internal | ProjectFeature::DISABLED  | :guest      | false
      :internal | ProjectFeature::DISABLED  | :anonymous  | false
      :private  | ProjectFeature::ENABLED   | :admin      | true
      :private  | ProjectFeature::ENABLED   | :owner      | true
      :private  | ProjectFeature::ENABLED   | :maintainer | true
      :private  | ProjectFeature::ENABLED   | :developer  | true
      :private  | ProjectFeature::ENABLED   | :reporter   | true
      :private  | ProjectFeature::ENABLED   | :guest      | false
      :private  | ProjectFeature::ENABLED   | :anonymous  | false
      :private  | ProjectFeature::PRIVATE   | :admin      | true
      :private  | ProjectFeature::PRIVATE   | :owner      | true
      :private  | ProjectFeature::PRIVATE   | :maintainer | true
      :private  | ProjectFeature::PRIVATE   | :developer  | true
      :private  | ProjectFeature::PRIVATE   | :reporter   | true
      :private  | ProjectFeature::PRIVATE   | :guest      | false
      :private  | ProjectFeature::PRIVATE   | :anonymous  | false
      :private  | ProjectFeature::DISABLED  | :admin      | false
      :private  | ProjectFeature::DISABLED  | :owner      | false
      :private  | ProjectFeature::DISABLED  | :maintainer | false
      :private  | ProjectFeature::DISABLED  | :developer  | false
      :private  | ProjectFeature::DISABLED  | :reporter   | false
      :private  | ProjectFeature::DISABLED  | :guest      | false
      :private  | ProjectFeature::DISABLED  | :anonymous  | false
    end

    with_them do
      let(:current_user) { send(role) }
      let(:project) { send("#{project_visibility}_project") }

      before do
        enable_admin_mode!(admin) if role == :admin
        project.project_feature.update!(container_registry_access_level: access_level)
      end

      it 'allows/disallows the abilities based on the container_registry feature access level' do
        if allowed
          expect_allowed(*permissions_abilities(role))
          expect_disallowed(*(all_permissions - permissions_abilities(role)))
        else
          expect_disallowed(*all_permissions)
        end
      end

      it 'allows build_read_container_image to admins who are also team members' do
        if allowed && role == :admin
          project.add_reporter(current_user)

          expect_allowed(:build_read_container_image)
        end
      end
    end

    context 'with external guest users' do
      where(:project_visibility, :access_level, :allowed) do
        :public   | ProjectFeature::ENABLED  | true
        :public   | ProjectFeature::PRIVATE  | false
        :public   | ProjectFeature::DISABLED | false

        :internal | ProjectFeature::ENABLED  | true
        :internal | ProjectFeature::PRIVATE  | false
        :internal | ProjectFeature::DISABLED | false

        :private  | ProjectFeature::ENABLED  | false
        :private  | ProjectFeature::PRIVATE  | false
        :private  | ProjectFeature::DISABLED | false
      end

      with_them do
        let(:current_user) { guest }
        let(:project) { send("#{project_visibility}_project") }

        before do
          project.project_feature.update!(container_registry_access_level: access_level)
          current_user.update_column(:external, true)
        end

        it 'allows/disallows the abilities based on the container_registry feature access level' do
          if allowed
            expect_allowed(*permissions_abilities(:guest))
            expect_disallowed(*(all_permissions - permissions_abilities(:guest)))
          else
            expect_disallowed(*all_permissions)
          end
        end
      end
    end

    # Overrides `permissions_abilities` defined below to be suitable for container_image policies
    def permissions_abilities(role)
      case role
      when :admin
        if project_visibility == :private || access_level == ProjectFeature::PRIVATE
          maintainer_operations_permissions - admin_excluded_permissions
        else
          maintainer_operations_permissions
        end
      when :maintainer, :owner
        maintainer_operations_permissions
      when :developer
        developer_operations_permissions
      when :reporter, :guest
        guest_operations_permissions
      when :anonymous
        anonymous_operations_permissions
      else
        raise "Unknown role #{role}"
      end
    end
  end

  describe 'update_runners_registration_token' do
    # Override project with a version with namespace_settings
    let(:project) { project_with_runner_registration_token }
    let(:allow_runner_registration_token) { true }

    before do
      stub_application_setting(allow_runner_registration_token: allow_runner_registration_token)
    end

    context 'when anonymous' do
      let(:current_user) { anonymous }

      it { is_expected.not_to be_allowed(:update_runners_registration_token) }
    end

    context 'admin' do
      let(:current_user) { create(:admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:update_runners_registration_token) }

        context 'with registration tokens disabled' do
          let(:allow_runner_registration_token) { false }

          it { is_expected.to be_disallowed(:update_runners_registration_token) }
        end
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:update_runners_registration_token) }
      end
    end

    %w[guest reporter developer].each do |role|
      context role do
        let(:current_user) { send(role) }

        it { is_expected.to be_disallowed(:update_runners_registration_token) }
      end
    end

    %w[maintainer owner].each do |role|
      context role do
        let(:current_user) { send(role) }

        it { is_expected.to be_allowed(:update_runners_registration_token) }

        context 'with registration tokens disabled' do
          let(:allow_runner_registration_token) { false }

          it { is_expected.to be_disallowed(:update_runners_registration_token) }
        end
      end
    end
  end

  describe 'register_project_runners' do
    # Override project with a version with namespace_settings
    let(:project) { project_with_runner_registration_token }
    let(:allow_runner_registration_token) { true }

    before do
      stub_application_setting(allow_runner_registration_token: allow_runner_registration_token)
    end

    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:register_project_runners) }

        context 'with project runner registration disabled' do
          before do
            stub_application_setting(valid_runner_registrars: ['group'])
          end

          it { is_expected.to be_allowed(:register_project_runners) }

          context 'with registration tokens disabled' do
            let(:allow_runner_registration_token) { false }

            it { is_expected.to be_disallowed(:register_project_runners) }
          end
        end

        context 'with specific project runner registration disabled' do
          before do
            project.update!(runner_registration_enabled: false)
          end

          it { is_expected.to be_allowed(:register_project_runners) }
        end
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:register_project_runners) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:register_project_runners) }

      context 'with registration tokens disabled' do
        let(:allow_runner_registration_token) { false }

        it { is_expected.to be_disallowed(:register_project_runners) }
      end

      context 'with project runner registration disabled' do
        before do
          stub_application_setting(valid_runner_registrars: ['group'])
        end

        it { is_expected.to be_disallowed(:register_project_runners) }
      end

      context 'with specific project runner registration disabled' do
        before do
          project.update!(runner_registration_enabled: false)
        end

        it { is_expected.to be_disallowed(:register_project_runners) }
      end
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:register_project_runners) }

      context 'with registration tokens disabled' do
        let(:allow_runner_registration_token) { false }

        it { is_expected.to be_disallowed(:register_project_runners) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:register_project_runners) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:register_project_runners) }
    end

    context 'with non member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:register_project_runners) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:register_project_runners) }
    end
  end

  describe 'create_runner' do
    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:create_runner) }

        context 'with project runner registration disabled' do
          before do
            stub_application_setting(valid_runner_registrars: ['group'])
          end

          it { is_expected.to be_allowed(:create_runner) }
        end

        context 'with specific project runner registration disabled' do
          before do
            project.update!(runner_registration_enabled: false)
          end

          it { is_expected.to be_allowed(:create_runner) }
        end
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:create_runner) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:create_runner) }

      context 'with project runner registration disabled' do
        before do
          stub_application_setting(valid_runner_registrars: ['group'])
        end

        it { is_expected.to be_disallowed(:create_runner) }
      end

      context 'with specific project runner registration disabled' do
        before do
          project.update!(runner_registration_enabled: false)
        end

        it { is_expected.to be_disallowed(:create_runner) }
      end
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:create_runner) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:create_runner) }
    end
  end

  describe 'admin_project_runners' do
    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:create_runner) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:create_runner) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:create_runner) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:create_runner) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:create_runner) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:create_runner) }
    end
  end

  describe 'read_project_runners' do
    subject(:policy) { described_class.new(user, project) }

    context 'with maintainer' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:read_project_runners) }
    end

    context 'with admin', :enable_admin_mode do
      let(:user) { admin }

      it { is_expected.to be_allowed(:read_project_runners) }
    end

    context 'with reporter' do
      let(:user) { reporter }

      it { is_expected.to be_disallowed(:read_project_runners) }
    end

    context 'when the user is not part of the project' do
      let(:user) { non_member }

      it { is_expected.to be_disallowed(:read_project_runners) }
    end
  end

  describe 'update_sentry_issue' do
    using RSpec::Parameterized::TableSyntax

    where(:role, :allowed) do
      :owner      | true
      :maintainer | true
      :developer  | true
      :reporter   | false
      :guest      | false
    end

    let(:project) { public_project }
    let(:current_user) { public_send(role) }

    with_them do
      it do
        expect(subject.can?(:update_sentry_issue)).to be(allowed)
      end
    end
  end

  describe 'read_milestone' do
    context 'when project is public' do
      let(:project) { public_project_in_group }

      context 'and issues and merge requests are private' do
        before do
          project.project_feature.update!(
            issues_access_level: ProjectFeature::PRIVATE,
            merge_requests_access_level: ProjectFeature::PRIVATE
          )
        end

        context 'when user is an inherited member from the group' do
          context 'and user is a guest' do
            let(:current_user) { inherited_guest }

            it { is_expected.to be_allowed(:read_milestone) }
          end

          context 'and user is a reporter' do
            let(:current_user) { inherited_reporter }

            it { is_expected.to be_allowed(:read_milestone) }
          end

          context 'and user is a developer' do
            let(:current_user) { inherited_developer }

            it { is_expected.to be_allowed(:read_milestone) }
          end
        end
      end
    end
  end

  describe 'role_enables_download_code' do
    using RSpec::Parameterized::TableSyntax

    context 'default roles' do
      let(:current_user) { public_send(role) }

      context 'public project' do
        let(:project) { public_project }

        where(:role, :allowed) do
          :owner      | true
          :maintainer | true
          :developer  | true
          :reporter   | true
          :guest      | true

          with_them do
            it do
              expect(subject.can?(:download_code)).to be(allowed)
            end
          end
        end
      end

      context 'private project' do
        let(:project) { private_project }

        where(:role, :allowed) do
          :owner      | true
          :maintainer | true
          :developer  | true
          :reporter   | true
          :guest      | false
        end

        with_them do
          it do
            expect(subject.can?(:download_code)).to be(allowed)
          end
        end
      end
    end
  end

  describe 'read_code' do
    let(:current_user) { create(:user) }

    before do
      allow(subject).to receive(:allowed?).and_call_original
      allow(subject).to receive(:allowed?).with(:download_code).and_return(can_download_code)
    end

    context 'when the current_user can download_code' do
      let(:can_download_code) { true }

      it { expect_allowed(:read_code) }
    end

    context 'when the current_user cannot download_code' do
      let(:can_download_code) { false }

      it { expect_disallowed(:read_code) }
    end
  end

  describe 'read_namespace_catalog' do
    let(:current_user) { owner }

    specify { is_expected.to be_disallowed(:read_namespace_catalog) }
  end

  describe 'add_catalog_resource' do
    using RSpec::Parameterized::TableSyntax

    let(:current_user) { public_send(role) }

    where(:role, :allowed) do
      :owner      | true
      :maintainer | false
      :developer  | false
      :reporter   | false
      :guest      | false
    end

    with_them do
      it do
        expect(subject.can?(:add_catalog_resource)).to be(allowed)
      end
    end
  end

  describe 'read_model_registry' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag_enabled, :current_user, :access_level, :allowed) do
      false | ref(:owner)      | Featurable::ENABLED  | false
      true  | ref(:guest)      | Featurable::ENABLED  | true
      true  | ref(:guest)      | Featurable::PRIVATE  | true
      true  | ref(:guest)      | Featurable::DISABLED | false
      true  | ref(:non_member) | Featurable::ENABLED  | true
      true  | ref(:non_member) | Featurable::PRIVATE  | false
      true  | ref(:non_member) | Featurable::DISABLED | false
    end
    with_them do
      before do
        stub_feature_flags(model_registry: feature_flag_enabled)
        project.project_feature.update!(model_registry_access_level: access_level)
      end

      if params[:allowed]
        it { expect_allowed(:read_model_registry) }
      else
        it { expect_disallowed(:read_model_registry) }
      end
    end
  end

  describe 'write_model_registry' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag_enabled, :current_user, :access_level, :allowed) do
      false | ref(:owner)      | Featurable::ENABLED  | false
      true  | ref(:reporter)   | Featurable::ENABLED  | true
      true  | ref(:reporter)   | Featurable::PRIVATE  | true
      true  | ref(:reporter)   | Featurable::DISABLED | false
      true  | ref(:guest)      | Featurable::ENABLED  | false
      true  | ref(:non_member) | Featurable::ENABLED  | false
    end
    with_them do
      before do
        stub_feature_flags(model_registry: feature_flag_enabled)
        project.project_feature.update!(model_registry_access_level: access_level)
      end

      if params[:allowed]
        it { expect_allowed(:write_model_registry) }
      else
        it { expect_disallowed(:write_model_registry) }
      end
    end
  end

  describe ':read_model_experiments' do
    using RSpec::Parameterized::TableSyntax

    where(:ff_ml_experiment_tracking, :current_user, :access_level, :allowed) do
      false | ref(:owner)      | Featurable::ENABLED  | false
      true  | ref(:guest)      | Featurable::ENABLED  | true
      true  | ref(:guest)      | Featurable::PRIVATE  | true
      true  | ref(:guest)      | Featurable::DISABLED | false
      true  | ref(:non_member) | Featurable::ENABLED  | true
      true  | ref(:non_member) | Featurable::PRIVATE  | false
      true  | ref(:non_member) | Featurable::DISABLED | false
    end
    with_them do
      before do
        stub_feature_flags(ml_experiment_tracking: ff_ml_experiment_tracking)
        project.project_feature.update!(model_experiments_access_level: access_level)
      end

      if params[:allowed]
        it { is_expected.to be_allowed(:read_model_experiments) }
      else
        it { is_expected.not_to be_allowed(:read_model_experiments) }
      end
    end
  end

  describe ':write_model_experiments' do
    using RSpec::Parameterized::TableSyntax

    where(:ff_ml_experiment_tracking, :current_user, :access_level, :allowed) do
      false | ref(:owner)      | Featurable::ENABLED  | false
      true  | ref(:reporter)   | Featurable::ENABLED  | true
      true  | ref(:reporter)   | Featurable::PRIVATE  | true
      true  | ref(:reporter)   | Featurable::DISABLED | false
      true  | ref(:guest)      | Featurable::ENABLED  | false
      true  | ref(:non_member) | Featurable::ENABLED  | false
    end
    with_them do
      before do
        stub_feature_flags(ml_experiment_tracking: ff_ml_experiment_tracking)
        project.project_feature.update!(model_experiments_access_level: access_level)
      end

      if params[:allowed]
        it { is_expected.to be_allowed(:write_model_experiments) }
      else
        it { is_expected.not_to be_allowed(:write_model_experiments) }
      end
    end
  end

  describe 'when project is created and owned by a banned user' do
    let_it_be(:project) { create(:project, :public) }

    let(:current_user) { guest }

    before do
      allow(project).to receive(:created_and_owned_by_banned_user?).and_return(true)
    end

    it { expect_disallowed(:read_project) }

    context 'when current user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:read_project) }
    end

    context 'when hide_projects_of_banned_users FF is disabled' do
      before do
        stub_feature_flags(hide_projects_of_banned_users: false)
      end

      it { expect_allowed(:read_project) }
    end
  end

  describe 'webhooks' do
    context 'when the current_user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:read_web_hook, :admin_web_hook) }
    end

    context 'when the current_user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:read_web_hook, :admin_web_hook) }
    end
  end

  describe 'build_push_code' do
    using RSpec::Parameterized::TableSyntax

    let(:policy) { :build_push_code }

    where(:user_role, :project_visibility, :push_repository_for_job_token_allowed, :self_referential_project, :allowed, :ff_disabled) do
      :maintainer | :public   | true  | true  | true  | false
      :owner      | :public   | true  | true  | true  | false
      :maintainer | :private  | true  | true  | true  | false
      :developer  | :public   | true  | true  | true  | false
      :reporter   | :public   | true  | true  | false | false
      :guest      | :public   | true  | true  | false | false
      :guest      | :private  | true  | true  | false | false
      :guest      | :internal | true  | true  | false | false
      :anonymous  | :public   | true  | true  | false | false
      :maintainer | :public   | false | true  | false | false
      :maintainer | :public   | true  | false | false | false
      :maintainer | :public   | false | false | false | false
      :maintainer | :public   | true  | true  | false | true
      :owner      | :public   | true  | true  | false | true
      :maintainer | :private  | true  | true  | false | true
      :developer  | :public   | true  | true  | false | true
      :reporter   | :public   | true  | true  | false | true
    end

    with_them do
      let(:current_user) do
        public_send(user_role)
      end

      let(:job) { build_stubbed(:ci_build, project: scope_project, user: current_user) }
      let(:project) { public_send("#{project_visibility}_project") }
      let(:self_referential_job) { build_stubbed(:ci_build, project: project, user: current_user) }
      let(:scope_project) { public_send(:private_project) }

      before do
        stub_feature_flags(allow_push_repository_for_job_token: false) if ff_disabled

        project.add_guest(guest)
        project.add_reporter(reporter)
        project.add_developer(developer)
        project.add_maintainer(maintainer)
        project.add_maintainer(owner)

        project.ci_inbound_job_token_scope_enabled = true
        project.save!

        ci_cd_settings = project.ci_cd_settings
        ci_cd_settings.push_repository_for_job_token_allowed = push_repository_for_job_token_allowed
        ci_cd_settings.save!

        if user_role != :anonymous
          if self_referential_project
            allow(current_user).to receive(:ci_job_token_scope).and_return(current_user.set_ci_job_token_scope!(self_referential_job))
          else
            allow(current_user).to receive(:ci_job_token_scope).and_return(current_user.set_ci_job_token_scope!(job))
          end
        end
      end

      it 'allows/disallows build_push_code' do
        if allowed
          is_expected.to be_allowed(:build_push_code)
        else
          is_expected.to be_disallowed(:build_push_code)
        end
      end
    end
  end

  private

  def project_subject(project_type)
    case project_type
    when :public
      public_project
    when :internal
      internal_project
    else
      private_project
    end
  end

  def user_subject(role)
    case role
    when :maintainer
      maintainer
    when :developer
      developer
    when :guest
      guest
    when :anonymous
      anonymous
    end
  end

  def permissions_abilities(role)
    case role
    when :maintainer
      maintainer_permissions
    when :developer
      developer_permissions
    else
      guest_permissions
    end
  end
end
