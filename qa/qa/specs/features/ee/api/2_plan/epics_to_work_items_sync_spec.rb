# frozen_string_literal: true

require 'airborne'

module QA
  # Spec can be removed once epic migration to work items is complete
  RSpec.describe 'Plan',
    only: { condition: -> { ENV["EPIC_SYNC_TEST"] == "true" } }, product_group: :product_planning do
    describe 'Legacy Epics to Work Items Migration' do
      let(:milestone_start_date) { (Date.today + 100).iso8601 }
      let(:milestone_due_date) { (Date.today + 120).iso8601 }
      let(:fixed_start_date) { Date.today.iso8601 }
      let(:fixed_due_date) { (Date.today + 90).iso8601 }
      let(:api_client) { Runtime::API::Client.new(:gitlab) }
      let(:group) { create(:group, path: "epic-work-item-group-#{SecureRandom.hex(8)}") }
      let(:project) { create(:project, name: "epic-work-item-project-#{SecureRandom.hex(8)}", group: group) }
      let(:allowed_time_offset) { 1.second }
      let(:legacy_epic) { create_epic }
      let(:work_item_epic) { group.work_item_epics.first }

      before do
        Flow::Login.sign_in
      end

      context 'when creating a legacy epic' do
        it 'creates a duplicate work item epic', :aggregate_failures,
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/465878' do
          compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
        end
      end

      context 'when updating an epic' do
        it 'syncs changes from legacy epic to work item epic', :aggregate_failures,
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/465880' do
          request = create_request("/groups/#{CGI.escape(group.full_path)}/epics/#{legacy_epic.iid}")
          put request.url, title: "this is an updated title", description: "this is an updated description"
          expect_status(200)

          legacy_epic.reload!

          compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
        end

        it 'syncs changes when adding an issue with milestone', :aggregate_failures,
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/465881' do
          legacy_epic = create_epic_issue_milestone[0]

          compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
        end

        it 'syncs changes when changing confidentiality', :aggregate_failures,
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/465882' do
          request = create_request("/groups/#{CGI.escape(group.full_path)}/epics/#{legacy_epic.iid}")
          put request.url, confidential: true
          expect_status(200)

          legacy_epic.reload!

          expect(legacy_epic.confidential).to eq(true)

          compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
        end
      end

      it 'syncs epics dates when editing a milestone', :aggregate_failures,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/465883' do
        legacy_epic, milestone = create_epic_issue_milestone
        new_milestone_start_date = (Date.today + 20).iso8601
        new_milestone_due_date = (Date.today + 30).iso8601

        # Update Milestone to different dates and see it reflecting in the epics
        request = create_request("/projects/#{project.id}/milestones/#{milestone.id}")
        put request.url, start_date: new_milestone_start_date, due_date: new_milestone_due_date
        expect_status(200)

        legacy_epic.reload!

        expect(legacy_epic.start_date_from_milestones).to eq(new_milestone_start_date)
        expect(legacy_epic.due_date_from_milestones).to eq(new_milestone_due_date)
        expect(legacy_epic.start_date).to eq(new_milestone_start_date)
        expect(legacy_epic.due_date).to eq(new_milestone_due_date)

        compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
      end

      private

      def compare_legacy_epic_to_work_item_epic(legacy_epic, work_item_epic)
        # base attributes check
        expect(work_item_epic.inspect).to eq(legacy_epic.inspect)
        expect(work_item_epic.epic_author).to eq(legacy_epic.epic_author)

        # variable dates check
        legacy_epic.epic_dates.each do |attribute, legacy_epic_value|
          work_item_value = work_item_epic.epic_dates[attribute]
          next if legacy_epic_value == work_item_value

          legacy_epic_date = DateTime.parse(legacy_epic_value) if legacy_epic_value.is_a?(String)
          work_item_epic_date = DateTime.parse(work_item_value) if work_item_value.is_a?(String)

          expect(legacy_epic_date).to be_truthy
          expect(work_item_epic_date).to be_truthy
          expect(legacy_epic_date - work_item_epic_date).to be < (allowed_time_offset),
            "expected #{attribute} value of #{work_item_epic_date}" \
              "to be within #{allowed_time_offset} seconds of #{legacy_epic_date}"
        end
      end

      def create_epic
        create(:epic,
          group: group,
          title: 'My New Epic',
          due_date_fixed: fixed_due_date,
          start_date_fixed: fixed_start_date,
          start_date_is_fixed: true,
          due_date_is_fixed: true)
      end

      def create_request(api_endpoint)
        Runtime::API::Request.new(api_client, api_endpoint)
      end

      def create_issue(milestone)
        create(:issue, title: 'My Test Issue', project: project, milestone: milestone)
      end

      def create_milestone(start_date, due_date)
        create(:project_milestone, project: project, start_date: start_date, due_date: due_date)
      end

      def create_epic_issue_milestone
        epic = create_epic
        milestone = create_milestone(milestone_start_date, milestone_due_date)
        issue = create_issue(milestone)
        add_issue_to_epic(epic, issue)
        use_epics_milestone_dates(epic)
        [epic, milestone]
      end

      def add_issue_to_epic(epic, issue)
        # Add Issue with milestone to an epic
        request = create_request("/groups/#{group.id}/epics/#{epic.iid}/issues/#{issue.id}")
        post request.url

        expect_status(201)
        expect_json('epic.title', 'My New Epic')
        expect_json('issue.title', 'My Test Issue')
      end

      def use_epics_milestone_dates(epic)
        # Update Epic to use Milestone Dates
        request = create_request("/groups/#{group.id}/epics/#{epic.iid}")
        put request.url, start_date_is_fixed: false, due_date_is_fixed: false
        expect_status(200)

        epic.reload!

        expect(epic.start_date_from_milestones).to eq(milestone_start_date)
        expect(epic.due_date_from_milestones).to eq(milestone_due_date)
        expect(epic.start_date_fixed).to eq(fixed_start_date)
        expect(epic.due_date_fixed).to eq(fixed_due_date)
        expect(epic.start_date).to eq(milestone_start_date)
        expect(epic.due_date).to eq(milestone_due_date)
      end
    end
  end
end
