# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MergeRequest'], feature_category: :code_review_workflow do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :approvals_required, :merge_trains_count, :merge_train_index,
      :approval_state, :finding_reports_comparer
    ).at_least
  end

  it { expect(described_class).to have_graphql_field(:approved, complexity: 2, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:approvals_left, complexity: 2, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:has_security_reports, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:security_reports_up_to_date_on_target_branch, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:suggested_reviewers) }
  it { expect(described_class).to have_graphql_field(:blocking_merge_requests) }
  it { expect(described_class).to have_graphql_field(:merge_request_diffs) }
  it { expect(described_class).to have_graphql_field(:policy_violations) }

  shared_context 'with a merge train' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:merge_request) { create(:merge_request, :on_train, target_project: project, source_project: project) }
    let_it_be(:current_user) { create :admin }
  end

  shared_context 'with a merge train and merge trains enabled' do
    include_context 'with a merge train'

    before do
      allow(project).to receive(:merge_trains_enabled?).and_return(true)
    end
  end

  describe '#merge_trains_count', feature_category: :merge_trains do
    subject(:resulting_count) { resolve_field(:merge_trains_count, merge_request, current_user: current_user) }

    context 'when merge trains are disabled' do
      include_context 'with a merge train'

      it 'the count is null' do
        expect(resulting_count).to be_nil
      end
    end

    context 'when merge trains are enabled' do
      include_context 'with a merge train and merge trains enabled'

      it 'gets the count' do
        expect(resulting_count).to be 1
      end
    end
  end

  describe '#merge_train_index', feature_category: :merge_trains do
    subject(:resulting_index) { resolve_field(:merge_train_index, merge_request, current_user: current_user) }

    context 'when merge trains are disabled' do
      include_context 'with a merge train'

      it 'the count is null' do
        expect(resulting_index).to be_nil
      end
    end

    context 'when merge trains are enabled' do
      include_context 'with a merge train and merge trains enabled'

      it 'gets the count' do
        expect(resulting_index).to be_zero
      end
    end
  end

  shared_examples_for 'avoids N+1 queries' do
    specify do
      GitlabSchema.execute(query, context: { current_user: user })

      # Clear batch loader cache to ensure there's no N+1 if batch loading isn't cached.
      BatchLoader::Executor.clear_current

      control = ActiveRecord::QueryRecorder.new { GitlabSchema.execute(query, context: { current_user: user }) }

      create_additional_resources

      # Clear batch loader cache to ensure there's no N+1 if batch loading isn't cached.
      BatchLoader::Executor.clear_current

      expect { GitlabSchema.execute(query, context: { current_user: user }) }.not_to exceed_query_limit(control)
    end
  end

  shared_examples_for 'field with approval rules related check' do
    let_it_be(:user) { project.owner }
    let_it_be(:users) { create_list(:user, 2) }
    let_it_be(:groups) { create_list(:group, 2) }

    let_it_be(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'source-branch-1'
      )
    end

    let_it_be(:protected_branches) { create_list(:protected_branch, 2, project: project) }

    let_it_be(:approval_project_rule_1) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_2) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_3) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    let_it_be(:approval_project_rule_4) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    before_all do
      users.each do |user|
        project.add_maintainer(user)
      end

      groups.each do |group|
        users = create_list(:user, 2)

        group.add_members(users, GroupMember::MAINTAINER)
      end

      setup_blocking_mrs(merge_request)
      setup_mr_diff_commit(merge_request)
      setup_approval_rules(merge_request)
    end

    before do
      stub_licensed_features(
        merge_request_approvers: true,
        multiple_approval_rules: true,
        blocking_merge_requests: true
      )
    end

    shared_examples_for 'avoids N+1 queries related to approval rules' do
      shared_examples_for 'avoids N+1 queries with additional resources' do
        it_behaves_like 'avoids N+1 queries' do
          let(:create_additional_resources) do
            mr_1 = create(
              :merge_request,
              source_project: project,
              source_branch: 'source-branch-2'
            )

            mr_2 = create(
              :merge_request,
              source_project: project,
              source_branch: 'source-branch-3'
            )

            mr_3 = create(
              :merge_request,
              source_project: project
            )

            setup_blocking_mrs(mr_1)
            setup_blocking_mrs(mr_2)
            setup_blocking_mrs(mr_3)
            setup_mr_diff_commit(mr_1)
            setup_mr_diff_commit(mr_2)
            setup_mr_diff_commit(mr_3)
            setup_approval_rules(mr_1)
            setup_approval_rules(mr_3)

            # Simulate a merged MR
            mr_3.mark_as_merged!
          end
        end
      end

      it_behaves_like 'avoids N+1 queries with additional resources'

      context 'when committers are not allowed to approve' do
        before do
          stub_ee_application_setting(prevent_merge_requests_committers_approval: true)
        end

        it_behaves_like 'avoids N+1 queries with additional resources'
      end
    end

    context 'when overriding approvers is disabled' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'
    end

    context 'when overriding approvers is enabled' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: false)
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'
    end

    def setup_blocking_mrs(merge_request)
      create(:merge_request_block, blocked_merge_request: merge_request)
    end

    def setup_mr_diff_commit(merge_request)
      user = create(:user)
      mr_diff_commit_user = create(:merge_request_diff_commit_user, email: user.email)

      create(
        :merge_request_diff_commit,
        merge_request_diff: merge_request.merge_request_diff,
        commit_author: mr_diff_commit_user,
        committer: mr_diff_commit_user
      )
    end

    def setup_approval_rules(merge_request)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_1, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_2, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_3, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_4, users: users, groups: groups)
      create(:any_approver_rule, merge_request: merge_request)
      create(:code_owner_rule, merge_request: merge_request, users: users, groups: groups)
      create(:report_approver_rule, merge_request: merge_request, users: users, groups: groups)

      create(:approval, merge_request: merge_request, user: users.last)
      create(:approval, merge_request: merge_request, user: groups.last.members.last.user)
    end
  end

  describe '#mergeable' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                mergeable
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#detailed_merge_status' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                detailedMergeStatus
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end
end
