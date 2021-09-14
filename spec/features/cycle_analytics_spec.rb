# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Value Stream Analytics', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:stage_table_selector) { '[data-testid="vsa-stage-table"]' }
  let_it_be(:stage_table_event_selector) { '[data-testid="vsa-stage-event"]' }
  let_it_be(:metrics_selector) { "[data-testid='vsa-time-metrics']" }
  let_it_be(:metric_value_selector) { "[data-testid='displayValue']" }

  let(:stage_table) { page.find(stage_table_selector) }
  let(:project) { create(:project, :repository) }
  let(:issue) { create(:issue, project: project, created_at: 2.days.ago) }
  let(:milestone) { create(:milestone, project: project) }
  let(:mr) { create_merge_request_closing_issue(user, project, issue, commit_message: "References #{issue.to_reference}") }
  let(:pipeline) { create(:ci_empty_pipeline, status: 'created', project: project, ref: mr.source_branch, sha: mr.source_branch_sha, head_pipeline_of: mr) }

  def metrics_values
    page.find(metrics_selector).all(metric_value_selector).collect(&:text)
  end

  def set_daterange(from_date, to_date)
    page.find(".js-daterange-picker-from input").set(from_date)
    page.find(".js-daterange-picker-to input").set(to_date)
    wait_for_all_requests
  end

  context 'as an allowed user' do
    context 'when project is new' do
      before do
        project.add_maintainer(user)
        sign_in(user)

        visit project_cycle_analytics_path(project)
        wait_for_requests
      end

      it 'displays metrics with relevant values' do
        expect(metrics_values).to eq(['-'] * 4)
      end

      it 'shows active stage with empty message' do
        expect(page).to have_selector('.gl-path-active-item-indigo', text: 'Issue')
        expect(page).to have_content("We don't have enough data to show this stage.")
      end
    end

    context "when there's value stream analytics data" do
      # NOTE: in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68595 travel back
      # 5 days in time before we create data for these specs, to mitigate some flakiness
      # So setting the date range to be the last 2 days should skip past the existing data
      from = 2.days.ago.strftime("%Y-%m-%d")
      to = 1.day.ago.strftime("%Y-%m-%d")

      around do |example|
        travel_to(5.days.ago) { example.run }
      end

      before do
        project.add_maintainer(user)
        create_list(:issue, 2, project: project, created_at: 2.weeks.ago, milestone: milestone)

        create_cycle(user, project, issue, mr, milestone, pipeline)
        deploy_master(user, project)

        issue.metrics.update!(first_mentioned_in_commit_at: issue.metrics.first_associated_with_milestone_at + 1.hour)
        merge_request = issue.merge_requests_closing_issues.first.merge_request
        merge_request.update!(created_at: issue.metrics.first_associated_with_milestone_at + 1.hour)
        merge_request.metrics.update!(
          latest_build_started_at: merge_request.created_at + 3.hours,
          latest_build_finished_at: merge_request.created_at + 4.hours,
          merged_at: merge_request.created_at + 4.hours,
          first_deployed_to_production_at: merge_request.created_at + 5.hours
        )

        sign_in(user)
        visit project_cycle_analytics_path(project)

        wait_for_requests
      end

      it 'displays metrics' do
        metrics_tiles = page.find(metrics_selector)

        aggregate_failures 'with relevant values' do
          expect(metrics_tiles).to have_content('Commit')
          expect(metrics_tiles).to have_content('Deploy')
          expect(metrics_tiles).to have_content('Deployment Frequency')
          expect(metrics_tiles).to have_content('New Issue')
        end
      end

      it 'shows data on each stage', :sidekiq_might_not_need_inline do
        expect_issue_to_be_present

        click_stage('Plan')
        expect_issue_to_be_present

        click_stage('Code')
        expect_merge_request_to_be_present

        click_stage('Test')
        expect_merge_request_to_be_present

        click_stage('Review')
        expect_merge_request_to_be_present

        click_stage('Staging')
        expect_merge_request_to_be_present
      end

      it 'can filter the issues by date' do
        expect(stage_table.all(stage_table_event_selector).length).to eq(3)

        set_daterange(from, to)

        expect(stage_table.all(stage_table_event_selector).length).to eq(0)
      end

      it 'can filter the metrics by date' do
        expect(metrics_values).to eq(["3.0", "2.0", "1.0", "0.0"])

        set_daterange(from, to)

        expect(metrics_values).to eq(['-'] * 4)
      end
    end
  end

  context "as a guest" do
    before do
      project.add_developer(user)
      project.add_guest(guest)

      create_cycle(user, project, issue, mr, milestone, pipeline)
      deploy_master(user, project)

      sign_in(guest)
      visit project_cycle_analytics_path(project)
      wait_for_requests
    end

    it 'does not show the commit stats' do
      expect(page.find(metrics_selector)).not_to have_selector("#commits")
    end

    it 'needs permissions to see restricted stages' do
      expect(find(stage_table_selector)).to have_content(issue.title)

      click_stage('Code')
      expect(find(stage_table_selector)).to have_content('You need permission.')

      click_stage('Review')
      expect(find(stage_table_selector)).to have_content('You need permission.')
    end
  end

  def expect_issue_to_be_present
    expect(find(stage_table_selector)).to have_content(issue.title)
    expect(find(stage_table_selector)).to have_content(issue.author.name)
    expect(find(stage_table_selector)).to have_content("##{issue.iid}")
  end

  def expect_merge_request_to_be_present
    expect(find(stage_table_selector)).to have_content(mr.title)
    expect(find(stage_table_selector)).to have_content(mr.author.name)
    expect(find(stage_table_selector)).to have_content("!#{mr.iid}")
  end

  def click_stage(stage_name)
    find('.gl-path-nav-list-item', text: stage_name).click
    wait_for_requests
  end
end
