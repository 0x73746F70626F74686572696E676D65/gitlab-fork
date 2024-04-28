# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::TreeRestorer, feature_category: :importers do
  include ImportExport::CommonUtil

  subject(:restored_project_json) { project_tree_restorer.restore }

  let(:shared) { project.import_export_shared }
  let(:project_tree_restorer) { described_class.new(user: user, shared: shared, project: project) }

  describe 'epics' do
    let_it_be(:user) { create(:user) }

    before do
      setup_import_export_config('group')
      stub_licensed_features(epics: true)
    end

    context 'with group' do
      let_it_be(:project) do
        group = create(:group, :private)
        group.add_maintainer(user)
        create(:project,
          :builds_disabled,
          :issues_disabled,
          name: 'project',
          path: 'project',
          group: group)
      end

      let(:issue) { project.issues.find_by_title('Issue with Epic') }

      context 'with pre-existing epic' do
        let_it_be(:epic) { create(:epic, title: 'An epic', group: project.group) }

        it 'associates epics' do
          project = Project.find_by_path('project')

          expect { restored_project_json }.not_to change { Epic.count }
          expect(project.group.epics.count).to eq(1)
          expect(issue.epic).to eq(epic)
          expect(issue.epic_issue.relative_position).not_to be_nil
          expect(project.group.work_items.count).to eq(1)

          epic = project.group.epics.first
          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end

      context 'without pre-existing epic' do
        it 'creates epic' do
          project = Project.find_by_path('project')

          expect { restored_project_json }.to change { Epic.count }.from(0).to(1)
          expect(project.group.epics.count).to eq(1)

          expect(issue.epic).not_to be_nil
          expect(issue.epic_issue.relative_position).not_to be_nil
          expect(project.group.work_items.count).to eq(1)

          epic = project.group.epics.first
          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end

        it 'imports group epics into destination group and creates work items' do
          group = project.group
          group.epics.delete_all

          expect { restored_project_json }
            .to change { Epic.count }.from(0).to(1)
            .and change { WorkItem.with_issue_type(:epic).count }.from(0).to(1)
            .and change { WorkItem.with_issue_type(:issue).count }.from(0).to(3)

          expect(group.epics.count).to eq(1)
          expect(group.work_items.count).to eq(1)

          group.epics.each do |epic|
            expect(epic.work_item).to be_present
          end
        end
      end
    end

    context 'with personal namespace' do
      let_it_be(:project) do
        create(:project,
          :builds_disabled,
          :issues_disabled,
          name: 'project',
          path: 'project',
          namespace: user.namespace)
      end

      it 'ignores epic relation' do
        project = Project.find_by_path('project')

        expect { restored_project_json }.not_to change { Epic.count }
        expect(project.import_failures.size).to eq(0)
      end
    end
  end

  describe 'restores `protected_environments` with `deploy_access_levels`' do
    let_it_be(:user) { create(:admin, email: 'user_1@gitlabexample.com') }
    let_it_be(:second_user) { create(:user, email: 'user_2@gitlabexample.com') }
    let_it_be(:project) do
      create(:project, :builds_disabled, :issues_disabled,
        { name: 'project', path: 'project' })
    end

    before do
      setup_import_export_config('complex')
      restored_project_json
    end

    specify do
      aggregate_failures do
        expect(project.protected_environments.count).to eq(1)

        protected_env = project.protected_environments.first
        expect(protected_env.deploy_access_levels.count).to eq(1)
      end
    end
  end

  describe 'push_rules' do
    let_it_be(:project) { create(:project, name: 'project', path: 'project') }

    let(:user) { create(:user) }

    before do
      setup_import_export_config('complex', 'ee')
    end

    it 'creates push rules' do
      project = Project.find_by_path('project')

      expect { restored_project_json }.to change { PushRule.count }.from(0).to(1)

      expect(project.push_rule.force_push_regex).to eq("MustContain")
      expect(project.push_rule.commit_message_negative_regex).to eq("MustNotContain")
      expect(project.push_rule.max_file_size).to eq(1)
      expect(project.push_rule.deny_delete_tag).to be_truthy
    end
  end

  describe 'approval_rules' do
    let_it_be(:project) { create(:project, name: 'project', path: 'project') }

    let(:user) { create(:user) }

    before do
      setup_import_export_config('complex', 'ee')
      restored_project_json
    end

    it 'creates approval rules and its associations' do
      project = Project.find_by_path('project')

      expect(ApprovalProjectRule.count).to eq(1)
      approval_rule = project.approval_rules.first
      protected_branch = project.protected_branches.find_by(name: "master")

      expect(approval_rule.name).to eq("MustContain")
      expect(approval_rule.approvals_required).to eq(1)

      expect(approval_rule.approval_project_rules_users.count).to eq(1)
      expect(approval_rule.approval_project_rules_users.first).to have_attributes(approval_project_rule_id: approval_rule.id, user_id: user.id)

      expect(approval_rule.approval_project_rules_protected_branches.count).to eq(1)
      expect(approval_rule.approval_project_rules_protected_branches.first).to have_attributes(approval_project_rule_id: approval_rule.id, protected_branch_id: protected_branch.id)
    end
  end

  describe 'protected branches' do
    let_it_be(:project) { create(:project, :in_group, name: 'project', path: 'project') }
    let(:user) { create(:user) }

    subject(:protected_branch) { project.protected_branches.find_by(name: "master") }

    context 'when user is admin', :enable_admin_mode do
      before do
        user.update!(admin: true)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'creates all access levels' do
        expect(project.protected_branches.count).to eq(1)

        expect(protected_branch.merge_access_levels.for_role.count).to eq(1)
        expect(protected_branch.merge_access_levels.by_user(user).count).to eq(1)

        expect(protected_branch.push_access_levels.for_role.count).to eq(1)
        expect(protected_branch.push_access_levels.by_user(user).count).to eq(1)

        expect(protected_branch.unprotect_access_levels.for_role.count).to eq(1)
        expect(protected_branch.unprotect_access_levels.by_user(user).count).to eq(1)
      end
    end

    context 'when user is the group owner' do
      before do
        project.group.add_owner(user)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'creates all access levels' do
        expect(project.protected_branches.count).to eq(1)

        expect(protected_branch.merge_access_levels.for_role.count).to eq(1)
        expect(protected_branch.merge_access_levels.by_user(user).count).to eq(1)

        expect(protected_branch.push_access_levels.for_role.count).to eq(1)
        expect(protected_branch.push_access_levels.by_user(user).count).to eq(1)

        expect(protected_branch.unprotect_access_levels.for_role.count).to eq(1)
        expect(protected_branch.unprotect_access_levels.by_user(user).count).to eq(1)
      end
    end

    context 'when user is maintainer' do
      before do
        project.group.add_maintainer(user)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'excludes access levels assigned to users' do
        expect(project.protected_branches.count).to eq(1)

        expect(protected_branch.merge_access_levels.for_role.count).to eq(1)
        expect(protected_branch.merge_access_levels.for_user.count).to eq(0)

        expect(protected_branch.push_access_levels.for_role.count).to eq(1)
        expect(protected_branch.push_access_levels.for_user.count).to eq(0)

        expect(protected_branch.unprotect_access_levels.for_role.count).to eq(1)
        expect(protected_branch.unprotect_access_levels.for_user.count).to eq(0)
      end
    end
  end

  describe 'protected tags' do
    let_it_be(:project) { create(:project, :in_group, name: 'project', path: 'project') }
    let(:user) { create(:user) }

    context 'when user is admin', :enable_admin_mode do
      before do
        user.update!(admin: true)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'creates all access levels' do
        project = Project.find_by_path('project')

        protected_tag = project.protected_tags.find_by(name: "v*")

        expect(project.protected_tags.count).to eq(1)
        expect(protected_tag.create_access_levels.for_role.count).to eq(1)
        expect(protected_tag.create_access_levels.by_user(user).count).to eq(1)
      end
    end

    context 'when user is the group owner' do
      before do
        project.group.add_owner(user)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'creates all access levels' do
        project = Project.find_by_path('project')

        protected_tag = project.protected_tags.find_by(name: "v*")

        expect(project.protected_tags.count).to eq(1)
        expect(protected_tag.create_access_levels.for_role.count).to eq(1)
        expect(protected_tag.create_access_levels.by_user(user).count).to eq(1)
      end
    end

    context 'when user is maintainer' do
      before do
        project.group.add_maintainer(user)
        setup_import_export_config('complex', 'ee')
        restored_project_json
      end

      it 'excludes access levels assigned to users' do
        project = Project.find_by_path('project')

        protected_tag = project.protected_tags.find_by(name: "v*")

        expect(project.protected_tags.count).to eq(1)
        expect(protected_tag.create_access_levels.for_role.count).to eq(1)
        expect(protected_tag.create_access_levels.for_user.count).to eq(0)
      end
    end
  end

  describe 'boards' do
    let_it_be(:project) { create(:project, :builds_enabled, :issues_disabled, name: 'project', path: 'project') }

    let(:user) { create(:user) }

    before do
      setup_import_export_config('complex')
      restored_project_json
    end

    it 'has milestone associated with the issue board' do
      expect(Project.find_by_path('project').boards.find_by_name('TestBoardABC').milestone.name).to eq('test milestone')
    end

    it 'has milestone associated with the issue board list' do
      expect(Project.find_by_path('project').boards.find_by_name('TestBoardABC').lists.first.milestone.name).to eq('test milestone')
    end
  end

  describe 'resource iteration events' do
    let(:user) { create(:user) }
    let(:issue) { project.issues.find_by_title('Issue with Epic') }

    before do
      setup_import_export_config('group')
    end

    context 'when project is associated with a group' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }
      let(:cadence) { create(:iterations_cadence, group: group, title: 'iterations cadence') }

      before do
        group.add_maintainer(user)
      end

      it 'restores iteration events' do
        iteration = create(:iteration, iid: 5, start_date: '2022-08-15', due_date: '2022-08-21', iterations_cadence: cadence)

        expect { restored_project_json }.to change { ResourceIterationEvent.count }.from(0).to(1)

        event = issue.resource_iteration_events.first

        expect(event.action).to eq('add')
        expect(event.iteration).to eq(iteration)
      end

      context 'when iterations cadence does not match' do
        let(:cadence) { create(:iterations_cadence, group: group, title: 'non matching cadence') }

        it 'does not restore iteration events' do
          create(:iteration, iid: 5, start_date: '2022-08-15', due_date: '2022-08-21', iterations_cadence: cadence)

          expect { restored_project_json }.not_to change { ResourceIterationEvent.count }
        end
      end

      context 'when iteration could not be found' do
        it 'does not restore iteration events' do
          expect { restored_project_json }.not_to change { ResourceIterationEvent.count }

          expect(issue.resource_iteration_events.count).to eq(0)
        end
      end
    end

    context 'when project is not associated with a group' do
      let(:project) { create(:project) }

      it 'does not restore iteration events' do
        expect { restored_project_json }.not_to change { ResourceIterationEvent.count }

        expect(issue.resource_iteration_events.count).to eq(0)
      end
    end
  end
end
