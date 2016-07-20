require 'spec_helper'

describe Issues::BulkUpdateService, services: true do
  let(:user)    { create(:user) }
  let(:project) { create(:empty_project, namespace: user.namespace) }

  def bulk_update(issues, extra_params = {})
    bulk_update_params = extra_params
      .reverse_merge(issues_ids: Array(issues).map(&:id).join(','))

    Issues::BulkUpdateService.new(project, user, bulk_update_params).execute
  end

  describe 'close issues' do
    let(:issues) { create_list(:issue, 2, project: project) }

    it 'succeeds and returns the correct number of issues updated' do
      result = bulk_update(issues, state_event: 'close')

      expect(result[:success]).to be_truthy
      expect(result[:count]).to eq(issues.count)
    end

    it 'closes all the issues passed' do
      bulk_update(issues, state_event: 'close')

      expect(project.issues.opened).to be_empty
      expect(project.issues.closed).not_to be_empty
    end
  end

  describe 'reopen issues' do
    let(:issues) { create_list(:closed_issue, 2, project: project) }

    it 'succeeds and returns the correct number of issues updated' do
      result = bulk_update(issues, state_event: 'reopen')

      expect(result[:success]).to be_truthy
      expect(result[:count]).to eq(issues.count)
    end

    it 'reopens all the issues passed' do
      bulk_update(issues, state_event: 'reopen')

      expect(project.issues.closed).to be_empty
      expect(project.issues.opened).not_to be_empty
    end
  end

  describe 'updating assignee' do
    let(:issue) { create(:issue, project: project, assignee: user) }

    context 'when the new assignee ID is a valid user' do
      it 'succeeds' do
        result = bulk_update(issue, assignee_id: create(:user).id)

        expect(result[:success]).to be_truthy
        expect(result[:count]).to eq(1)
      end

      it 'updates the assignee to the use ID passed' do
        assignee = create(:user)

        expect { bulk_update(issue, assignee_id: assignee.id) }
          .to change { issue.reload.assignee }.from(user).to(assignee)
      end
    end

    context 'when the new assignee ID is -1' do
      it 'unassigns the issues' do
        expect { bulk_update(issue, assignee_id: -1) }
          .to change { issue.reload.assignee }.to(nil)
      end
    end

    context 'when the new assignee ID is not present' do
      it 'does not unassign' do
        expect { bulk_update(issue, assignee_id: nil) }
          .not_to change { issue.reload.assignee }
      end
    end
  end

  describe 'updating milestones' do
    let(:issue)     { create(:issue, project: project) }
    let(:milestone) { create(:milestone, project: project) }

    it 'succeeds' do
      result = bulk_update(issue, milestone_id: milestone.id)

      expect(result[:success]).to be_truthy
      expect(result[:count]).to eq(1)
    end

    it 'updates the issue milestone' do
      expect { bulk_update(issue, milestone_id: milestone.id) }
        .to change { issue.reload.milestone }.from(nil).to(milestone)
    end
  end

  describe 'updating labels' do
    def create_issue_with_labels(labels)
      create(:labeled_issue, project: project, labels: labels)
    end

    let(:bug) { create(:label, project: project) }
    let(:regression) { create(:label, project: project) }
    let(:merge_requests) { create(:label, project: project) }

    let(:issue_all_labels) { create_issue_with_labels([bug, regression, merge_requests]) }
    let(:issue_bug_and_regression) { create_issue_with_labels([bug, regression]) }
    let(:issue_bug_and_merge_requests) { create_issue_with_labels([bug, merge_requests]) }
    let(:issue_no_labels) { create(:issue, project: project) }
    let(:issues) { [issue_all_labels, issue_bug_and_regression, issue_bug_and_merge_requests, issue_no_labels] }

    let(:labels) { [] }
    let(:add_labels) { [] }
    let(:remove_labels) { [] }

    let(:bulk_update_params) do
      {
        label_ids:        labels.map(&:id),
        add_label_ids:    add_labels.map(&:id),
        remove_label_ids: remove_labels.map(&:id),
      }
    end

    before do
      bulk_update(issues, bulk_update_params)
    end

    context 'when label_ids are passed' do
      let(:issues) { [issue_all_labels, issue_no_labels] }
      let(:labels) { [bug, regression] }

      it 'updates the labels of all issues passed to the labels passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(eq(labels.map(&:id)))
      end

      it 'does not update issues not passed in' do
        expect(issue_bug_and_regression.label_ids).to contain_exactly(bug.id, regression.id)
      end

      context 'when those label IDs are empty' do
        let(:labels) { [] }

        it 'updates the issues passed to have no labels' do
          expect(issues.map(&:reload).map(&:label_ids)).to all(be_empty)
        end
      end
    end

    context 'when add_label_ids are passed' do
      let(:issues) { [issue_all_labels, issue_bug_and_merge_requests, issue_no_labels] }
      let(:add_labels) { [bug, regression, merge_requests] }

      it 'adds those label IDs to all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(include(*add_labels.map(&:id)))
      end

      it 'does not update issues not passed in' do
        expect(issue_bug_and_regression.label_ids).to contain_exactly(bug.id, regression.id)
      end
    end

    context 'when remove_label_ids are passed' do
      let(:issues) { [issue_all_labels, issue_bug_and_merge_requests, issue_no_labels] }
      let(:remove_labels) { [bug, regression, merge_requests] }

      it 'removes those label IDs from all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(be_empty)
      end

      it 'does not update issues not passed in' do
        expect(issue_bug_and_regression.label_ids).to contain_exactly(bug.id, regression.id)
      end
    end

    context 'when add_label_ids and remove_label_ids are passed' do
      let(:issues) { [issue_all_labels, issue_bug_and_merge_requests, issue_no_labels] }
      let(:add_labels) { [bug] }
      let(:remove_labels) { [merge_requests] }

      it 'adds the label IDs to all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(include(bug.id))
      end

      it 'removes the label IDs from all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids).flatten).not_to include(merge_requests.id)
      end

      it 'does not update issues not passed in' do
        expect(issue_bug_and_regression.label_ids).to contain_exactly(bug.id, regression.id)
      end
    end

    context 'when add_label_ids and label_ids are passed' do
      let(:issues) { [issue_all_labels, issue_bug_and_regression, issue_bug_and_merge_requests] }
      let(:labels) { [merge_requests] }
      let(:add_labels) { [regression] }

      it 'adds the label IDs to all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(include(regression.id))
      end

      it 'ignores the label IDs parameter' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(include(bug.id))
      end

      it 'does not update issues not passed in' do
        expect(issue_no_labels.label_ids).to be_empty
      end
    end

    context 'when remove_label_ids and label_ids are passed' do
      let(:issues) { [issue_no_labels, issue_bug_and_regression] }
      let(:labels) { [merge_requests] }
      let(:remove_labels) { [regression] }

      it 'remove the label IDs from all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids).flatten).not_to include(regression.id)
      end

      it 'ignores the label IDs parameter' do
        expect(issues.map(&:reload).map(&:label_ids).flatten).not_to include(merge_requests.id)
      end

      it 'does not update issues not passed in' do
        expect(issue_all_labels.label_ids).to contain_exactly(bug.id, regression.id, merge_requests.id)
      end
    end

    context 'when add_label_ids, remove_label_ids, and label_ids are passed' do
      let(:issues) { [issue_bug_and_merge_requests, issue_no_labels] }
      let(:labels) { [regression] }
      let(:add_labels) { [bug] }
      let(:remove_labels) { [merge_requests] }

      it 'adds the label IDs to all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids)).to all(include(bug.id))
      end

      it 'removes the label IDs from all issues passed' do
        expect(issues.map(&:reload).map(&:label_ids).flatten).not_to include(merge_requests.id)
      end

      it 'ignores the label IDs parameter' do
        expect(issues.map(&:reload).map(&:label_ids).flatten).not_to include(regression.id)
      end

      it 'does not update issues not passed in' do
        expect(issue_bug_and_regression.label_ids).to contain_exactly(bug.id, regression.id)
      end
    end
  end

  describe 'subscribe to issues' do
    let(:issues) { create_list(:issue, 2, project: project) }

    it 'subscribes the given user' do
      bulk_update(issues, subscription_event: 'subscribe')

      expect(issues).to all(be_subscribed(user))
    end
  end

  describe 'unsubscribe from issues' do
    let(:issues) do
      create_list(:closed_issue, 2, project: project) do |issue|
        issue.subscriptions.create(user: user, subscribed: true)
      end
    end

    it 'unsubscribes the given user' do
      bulk_update(issues, subscription_event: 'unsubscribe')

      issues.each do |issue|
        expect(issue).not_to be_subscribed(user)
      end
    end
  end
end
