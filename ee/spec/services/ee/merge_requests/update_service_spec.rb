# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UpdateService, :mailer, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:label) { create(:label, project: project) }
  let(:label2) { create(:label) }
  let(:current_user) { user }

  let(:merge_request) do
    create(
      :merge_request,
      :simple,
      title: 'Old title',
      description: "FYI #{user2.to_reference}",
      assignee_id: user3.id,
      source_project: project,
      author: create(:user)
    )
  end

  before do
    project.add_maintainer(user)
    project.add_developer(user2)
    project.add_developer(user3)
  end

  describe '#execute' do
    it_behaves_like 'existing issuable with scoped labels' do
      let(:issuable) { merge_request }
      let(:parent) { project }
    end

    context 'when MR is merged' do
      let(:issuable) { create(:merge_request, :simple, :merged, source_project: project) }
      let(:parent) { project }

      it_behaves_like 'merged MR with scoped labels and lock_on_merge'

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(enforce_locked_labels_on_merge: false)
        end

        it_behaves_like 'existing issuable with scoped labels'
      end
    end

    it_behaves_like 'service with multiple reviewers' do
      let(:opts) { {} }
      let(:execute) { update_merge_request(opts) }
    end

    def update_merge_request(opts)
      described_class.new(project: project, current_user: current_user, params: opts).execute(merge_request)
    end

    context 'when code owners changes' do
      let(:code_owner) { create(:user) }

      before do
        project.add_maintainer(code_owner)

        allow(merge_request).to receive(:code_owners).and_return([], [code_owner])
      end

      it 'does not create any todos' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { Todo.count }
      end

      it 'does not send any emails' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when approvals_before_merge changes' do
      using RSpec::Parameterized::TableSyntax

      where(:project_value, :mr_before_value, :mr_after_value, :result) do
        3 | 4   | 5   | 5
        3 | 4   | nil | 3
        3 | nil | 5   | 5
      end

      with_them do
        let(:project) { create(:project, :repository, approvals_before_merge: project_value) }

        it "does not update" do
          merge_request.update!(approvals_before_merge: mr_before_value)
          rule = create(:approval_merge_request_rule, merge_request: merge_request)

          update_merge_request(approvals_before_merge: mr_after_value)

          expect(rule.reload.approvals_required).to eq(0)
        end
      end
    end

    context 'for override requested changes' do
      context 'for user can not merge' do
        let(:current_user) { merge_request.author }

        it 'does not update' do
          expect do
            update_merge_request(override_requested_changes: true)
          end.not_to change { merge_request.override_requested_changes? }
        end
      end

      it 'updates override_requested_changes' do
        expect do
          update_merge_request(override_requested_changes: true)
        end.to change { merge_request.override_requested_changes? }.from(false).to(true)
      end

      it 'calls SystemNoteService.override_requested_changes' do
        expect_next_instance_of(::SystemNotes::MergeRequestsService) do |service|
          expect(service).to receive(:override_requested_changes).with(true)
        end

        update_merge_request(override_requested_changes: true)
      end

      it 'publishes a OverrideRequestedChanges state event' do
        expect do
          update_merge_request(override_requested_changes: true)
        end.to publish_event(MergeRequests::OverrideRequestedChangesStateEvent).with({
          current_user_id: current_user.id,
          merge_request_id: merge_request.id
        })
      end

      context 'when merge_when_checks_pass ff is off' do
        before do
          stub_feature_flags(merge_when_checks_pass: false)
        end

        it 'does not publish a OverrideRequestedChanges state event' do
          expect do
            update_merge_request(override_requested_changes: true)
          end.not_to publish_event(MergeRequests::OverrideRequestedChangesStateEvent)
        end
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { update_merge_request(override_requested_changes: true) }
      end
    end

    context 'merge' do
      let(:opts) { { merge: merge_request.diff_head_sha } }

      context 'when not approved' do
        before do
          merge_request.update!(approvals_before_merge: 1)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }
        it { expect(@merge_request.state).to eq('opened') }
      end

      context 'when approved' do
        before do
          merge_request.update!(approvals_before_merge: 1)
          merge_request.approvals.create!(user: user)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }

        it 'is in the "merge" state', :sidekiq_might_not_need_inline do
          expect(@merge_request.state).to eq('merged')
        end
      end
    end

    context 'when the approvers change' do
      let(:existing_approver) { create(:user) }
      let(:removed_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(removed_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
        end

        ActionMailer::Base.deliveries.clear
      end

      context 'when an approver is added and an approver is removed' do
        before do
          perform_enqueued_jobs do
            update_merge_request(approver_ids: [new_approver, existing_approver].map(&:id).join(','))
          end
        end

        it 'does not send emails to the new approvers' do
          should_not_email(new_approver)
        end

        it 'does not send emails to the existing approvers' do
          should_not_email(existing_approver)
        end

        it 'does not send emails to the removed approvers' do
          should_not_email(removed_approver)
        end
      end

      context 'when the approvers are set to the same values' do
        it 'does not create any todos' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { Todo.count }
        end

        it 'does not send any emails' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'updating target_branch' do
      let(:existing_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: "#{existing_approver.id},#{new_approver.id}")
        end

        merge_request.approvals.create!(user_id: existing_approver.id, patch_id_sha: merge_request.current_patch_id_sha)
      end

      shared_examples 'reset all approvals' do
        it 'resets approvals when target_branch is changed' do
          update_merge_request(target_branch: 'video')

          expect(merge_request.reload.approvals).to be_empty
        end

        it 'does not publish MergeRequests::ApprovalsResetEvent' do
          expect { update_merge_request(target_branch: 'video') }
            .not_to publish_event(MergeRequests::ApprovalsResetEvent)
        end
      end

      context 'when reset_approvals_on_push is set to true' do
        before do
          merge_request.target_project.update!(reset_approvals_on_push: true)
        end

        it_behaves_like 'reset all approvals'
      end

      context 'when selective_code_owner_removals is set to true' do
        before do
          merge_request.target_project.update!(
            reset_approvals_on_push: false,
            project_setting_attributes: { selective_code_owner_removals: true }
          )
        end

        it_behaves_like 'reset all approvals'
      end
    end

    context 'updating blocking merge requests' do
      it 'delegates to MergeRequests::UpdateBlocksService' do
        expect(MergeRequests::UpdateBlocksService)
          .to receive(:extract_params!)
          .and_return(:extracted_params)

        expect_next_instance_of(MergeRequests::UpdateBlocksService) do |service|
          expect(service.merge_request).to eq(merge_request)
          expect(service.current_user).to eq(user)
          expect(service.params).to eq(:extracted_params)

          expect(service).to receive(:execute)
        end

        update_merge_request({})
      end
    end

    context 'reset_approval_rules_to_defaults param' do
      let!(:existing_any_rule) { create(:any_approver_rule, merge_request: merge_request) }
      let!(:existing_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
      let(:rules) { merge_request.reload.approval_rules }

      shared_examples_for 'undeletable existing approval rules' do
        it 'does not delete existing approval rules' do
          aggregate_failures do
            expect(rules).not_to be_empty
            expect(rules).to include(existing_any_rule)
            expect(rules).to include(existing_rule)
          end
        end
      end

      context 'when approval rules can be overridden' do
        before do
          merge_request.project.update!(disable_overriding_approvers_per_merge_request: false)
        end

        context 'when not set' do
          before do
            update_merge_request({})
          end

          it_behaves_like 'undeletable existing approval rules'
        end

        context 'when set to false' do
          before do
            update_merge_request(reset_approval_rules_to_defaults: false)
          end

          it_behaves_like 'undeletable existing approval rules'
        end

        context 'when set to true' do
          context 'and approval_rules_attributes param is not set' do
            context 'when MR is not merged' do
              before do
                update_merge_request(reset_approval_rules_to_defaults: true)
              end

              it 'deletes existing approval rules' do
                expect(rules).to be_empty
              end
            end

            context 'when MR is merged' do
              let(:merge_request) { create(:merge_request) }

              before do
                merge_request.mark_as_merged!

                update_merge_request(reset_approval_rules_to_defaults: true)
              end

              it_behaves_like 'undeletable existing approval rules'
            end
          end

          context 'and approval_rules_attributes param is set' do
            context 'when MR is not merged' do
              before do
                update_merge_request(
                  reset_approval_rules_to_defaults: true,
                  approval_rules_attributes: [{ name: 'New Rule', approvals_required: 1 }]
                )
              end

              it 'deletes existing approval rules and creates new one' do
                aggregate_failures do
                  expect(rules.size).to eq(1)
                  expect(rules).not_to include(existing_any_rule)
                  expect(rules).not_to include(existing_rule)
                end
              end
            end

            context 'when MR is merged' do
              let(:merge_request) { create(:merge_request) }

              before do
                merge_request.mark_as_merged!

                update_merge_request(
                  reset_approval_rules_to_defaults: true,
                  approval_rules_attributes: [{ name: 'New Rule', approvals_required: 1 }]
                )
              end

              it_behaves_like 'undeletable existing approval rules'
            end
          end
        end
      end

      context 'when approval rules cannot be overridden' do
        before do
          merge_request.project.update!(disable_overriding_approvers_per_merge_request: true)
          update_merge_request(reset_approval_rules_to_defaults: true)
        end

        it_behaves_like 'undeletable existing approval rules'
      end
    end

    context 'when called inside an ActiveRecord transaction' do
      it 'does not attempt to update code owner approval rules' do
        expect(::MergeRequests::SyncCodeOwnerApprovalRulesWorker).not_to receive(:perform_async)

        update_merge_request(title: 'Title')
      end
    end

    context 'updating reviewer_ids' do
      it 'updates the tracking when user ids are valid' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .to receive(:track_users_review_requested)
          .with(users: [user, user2])

        update_merge_request(reviewer_ids: [user.id, user2.id])
      end
    end

    describe 'capture suggested_reviewer_ids', feature_category: :code_review_workflow do
      shared_examples 'not capturing suggested_reviewer_ids' do
        it 'does not capture the suggested_reviewer_ids and raise update error', :aggregate_failures do
          expect(MergeRequests::CaptureSuggestedReviewersAcceptedWorker).not_to receive(:perform_async)

          expect { update_merge_request(opts) }.not_to raise_error
        end
      end

      context 'when reviewer_ids is present' do
        context 'when suggested_reviewer_ids is present' do
          let(:opts) { { reviewer_ids: [user.id, user2.id], suggested_reviewer_ids: [user.id] } }

          it 'captures the suggested_reviewer_ids and does not raise update error', :aggregate_failures do
            expect(MergeRequests::CaptureSuggestedReviewersAcceptedWorker)
              .to receive(:perform_async)
              .with(merge_request.id, [user.id])

            expect { update_merge_request(opts) }.not_to raise_error
          end
        end

        context 'when suggested_reviewer_ids is blank' do
          let(:opts) { { reviewer_ids: [user.id, user2.id] } }

          it_behaves_like 'not capturing suggested_reviewer_ids'
        end
      end

      context 'when reviewer_ids is blank' do
        let(:opts) { { reviewer_ids: [], suggested_reviewer_ids: [user.id] } }

        it_behaves_like 'not capturing suggested_reviewer_ids'
      end
    end

    describe '#sync_any_merge_request_approval_rules' do
      let(:opts) { { target_branch: 'feature-2' } }
      let!(:any_merge_request_approval_rule) do
        create(:report_approver_rule, :any_merge_request, merge_request: merge_request)
      end

      subject(:execute) { update_merge_request(opts) }

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request.id)
        )

        execute
      end

      context 'when target_branch is not changing' do
        let(:opts) { {} }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'without any_merge_request rule' do
        let!(:any_merge_request_approval_rule) { nil }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#notify_for_policy_violations' do
      let(:opts) { { target_branch: 'feature-2' } }

      subject(:execute) { update_merge_request(opts) }

      it 'enqueues Security::SyncPolicyViolationCommentWorker' do
        expect(Security::SyncPolicyViolationCommentWorker).to receive(:perform_async).with(merge_request.id)

        execute
      end

      context 'when target_branch is not changing' do
        let(:opts) { {} }

        it 'does not enqueue Security::SyncPolicyViolationCommentWorker' do
          expect(Security::SyncPolicyViolationCommentWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe "merge request webhooks" do
      let(:service) { described_class.new(project: project, current_user: user, params: opts) }

      let(:opts) do
        {
          title: 'New title',
          description: 'Also please fix',
          assignee_ids: [user.id],
          reviewer_ids: [],
          state_event: 'close',
          label_ids: [label.id],
          target_branch: 'target',
          force_remove_source_branch: '1',
          discussion_locked: true
        }
      end

      before do
        allow(service).to receive(:execute_hooks)

        perform_enqueued_jobs do
          @merge_request = service.execute(merge_request)
          @merge_request.reload
        end
      end

      it 'executes hooks with update action' do
        expect(service).to have_received(:execute_hooks)
          .with(
            @merge_request,
            'update',
            old_associations: {
              approval_rules: [],
              labels: [],
              mentioned_users: [],
              assignees: [user3],
              reviewers: [],
              target_branch: "master",
              milestone: nil,
              total_time_spent: 0,
              time_change: 0,
              description: "FYI #{user2.to_reference}"
            }
          )
      end
    end

    describe 'JiraTitleDescriptionUpdateEvent' do
      let(:has_jira_key) { true }

      before do
        allow(merge_request).to receive(:has_jira_issue_keys?).and_return(has_jira_key)
      end

      context 'when the merge_when_checks_pass feature flag is on' do
        context 'when the description changes' do
          context 'when the description or title has a jira key' do
            it 'publishes a JiraTitleDescriptionUpdateEvent' do
              expected_data = {
                current_user_id: user.id,
                merge_request_id: merge_request.id
              }

              expect do
                update_merge_request(description: 'New description')
              end.to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent).with(expected_data)
            end
          end

          context 'when the description or title does not have a jira key' do
            let(:has_jira_key) { false }

            it 'does not publish a JiraTitleDescriptionUpdateEvent' do
              expect do
                update_merge_request(description: 'New description')
              end.not_to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent)
            end
          end
        end

        context 'when the title changes' do
          it 'publishes a JiraTitleDescriptionUpdateEvent' do
            expected_data = {
              current_user_id: user.id,
              merge_request_id: merge_request.id
            }

            expect do
              update_merge_request(title: 'New title')
            end.to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent).with(expected_data)
          end

          context 'when the description or title does not have a jira key' do
            let(:has_jira_key) { false }

            it 'does not publish a JiraTitleDescriptionUpdateEvent' do
              expect do
                update_merge_request(description: 'New description')
              end.not_to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent)
            end
          end
        end
      end

      context 'when the merge_when_checks_pass feature flag is off' do
        before do
          stub_feature_flags(merge_when_checks_pass: false)
        end

        context 'when the description changes' do
          it 'does not publish a JiraTitleDescriptionUpdateEvent' do
            expect do
              update_merge_request(description: 'New description')
            end.not_to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent)
          end
        end

        context 'when the title changes' do
          it 'publishes a JiraTitleDescriptionUpdateEvent' do
            expect do
              update_merge_request(title: 'New title')
            end.not_to publish_event(MergeRequests::JiraTitleDescriptionUpdateEvent)
          end
        end
      end
    end
  end
end
