# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group value stream analytics filters and data', :js, feature_category: :value_stream_management do
  include CycleAnalyticsHelpers

  let_it_be(:group) { create(:group, :with_organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, namespace: group, name: 'Cool fun project') }
  let_it_be(:sub_group) { create(:group, name: 'CA-sub-group', parent: group, organization_id: group.organization_id) }
  let_it_be(:sub_group_project) { create(:project, :repository, namespace: group, name: 'Cool sub group project') }
  let_it_be(:group_label1) { create(:group_label, group: group) }
  let_it_be(:group_label2) { create(:group_label, group: group) }
  let_it_be(:custom_value_stream_name) { "First custom value stream" }
  let_it_be(:predefined_date_ranges_dropdown_selector) { '[data-testid="vsa-predefined-date-ranges-dropdown"]' }
  let_it_be(:date_range_picker_selector) { '[data-testid="vsa-date-range-picker"]' }

  let(:milestone) { create(:milestone, project: project) }
  let(:mr) { create_merge_request_closing_issue(user, project, issue, commit_message: "References #{issue.to_reference}") }
  let(:pipeline) { create(:ci_empty_pipeline, status: 'created', project: project, ref: mr.source_branch, sha: mr.source_branch_sha, head_pipeline_of: mr) }

  let(:path_nav_selector) { '[data-testid="vsa-path-navigation"]' }
  let(:filter_bar_selector) { '[data-testid="vsa-filter-bar"]' }
  let(:card_metric_selector) { '[data-testid="vsa-metrics"] .gl-single-stat' }
  let(:vsd_link_selector) { '[data-testid="vsd-link"]' }

  let(:empty_state_selector) { '[data-testid="vsa-empty-state"]' }

  3.times do |i|
    let_it_be("issue_#{i}".to_sym) { create(:issue, title: "New Issue #{i}", project: sub_group_project, created_at: 2.days.ago) }
  end

  def select_stage(name)
    string_id = "CycleAnalyticsStage|#{name}"
    within_testid('vsa-path-navigation') do
      page.find('li', text: s_(string_id), match: :prefer_exact).click
    end

    wait_for_requests
  end

  def create_merge_request(id, extra_params = {})
    params = {
      id: id,
      target_branch: 'master',
      source_project: project2,
      source_branch: "feature-branch-#{id}",
      title: "mr name#{id}",
      created_at: 2.days.ago
    }.merge(extra_params)

    create(:merge_request, params)
  end

  def hover(path)
    page.driver.browser.action.move_to(page.find(path).native).perform
  end

  def group_vsd_link(target_group)
    "#{group_analytics_dashboards_path(target_group)}/value_streams_dashboard"
  end

  before do
    stub_licensed_features(cycle_analytics_for_groups: true, type_of_work_analytics: true, dora4_analytics: true, group_level_analytics_dashboard: true)

    group.add_owner(user)
    project.add_maintainer(user)

    sign_in(user)
  end

  shared_examples 'empty state' do
    it 'renders the empty state' do
      wait_for_requests
      expect(page).to have_selector(empty_state_selector)
      expect(page).to have_text(s_('CycleAnalytics|Custom value streams to measure your DevSecOps lifecycle'))
    end
  end

  context 'with no value streams' do
    before do
      select_group(group, empty_state_selector)
    end

    it_behaves_like 'empty state'
  end

  context 'with value streams' do
    def vsa_stages(selected_group)
      [
        create(:cycle_analytics_stage, namespace: selected_group, name: "Issue", relative_position: 1, start_event_identifier: :issue_created, end_event_identifier: :issue_closed),
        create(:cycle_analytics_stage, namespace: selected_group, name: "Code", relative_position: 2, start_event_identifier: :merge_request_created, end_event_identifier: :merge_request_merged),
        create(:cycle_analytics_stage, namespace: selected_group, name: "Milestone Plan", relative_position: 3, start_event_identifier: :issue_first_associated_with_milestone, end_event_identifier: :issue_first_added_to_board)
      ]
    end

    let(:issue) { create(:issue, project: project) }

    let_it_be(:value_stream) { create(:cycle_analytics_value_stream, namespace: group, name: custom_value_stream_name, stages: vsa_stages(group)) }

    let_it_be(:subgroup_value_stream) { create(:cycle_analytics_value_stream, namespace: sub_group, name: 'First subgroup value stream', stages: vsa_stages(sub_group)) }

    shared_examples 'has overview metrics' do
      before do
        wait_for_requests
      end

      it 'displays lifecycle metrics', :aggregate_failures do
        lead_time = page.all(card_metric_selector).first

        expect(lead_time).to have_content(_('Lead time'))
        expect(lead_time).to have_content('-')

        cycle_time = page.all(card_metric_selector)[1]

        expect(cycle_time).to have_content(_('Cycle time'))
        expect(cycle_time).to have_content('-')

        issue_count = page.all(card_metric_selector)[2]
        expect(issue_count).to have_content(n_('New issue', 'New issues', 4))

        deploys_count = page.all(card_metric_selector)[3]

        expect(deploys_count).to have_content(n_('Deploy', 'Deploys', 0))
        expect(deploys_count).to have_content('-')
      end
    end

    shared_examples 'has default filters' do
      it 'shows the projects filter' do
        expect(page).to have_selector('.dropdown-projects', visible: true)
      end

      it 'shows the filter bar' do
        expect(page).to have_selector(filter_bar_selector, visible: false)
      end

      it 'shows the predefined date ranges dropdown with `Last 30 days` selected' do
        page.within(predefined_date_ranges_dropdown_selector) do
          expect(page).to have_button('Last 30 days')
        end
      end

      it 'does not show the date range picker' do
        expect(page).not_to have_css(date_range_picker_selector)
      end
    end

    shared_examples 'group value stream analytics' do
      context 'stage table' do
        before do
          select_stage("Issue")
        end

        it 'displays an empty state and hide stage table' do
          expect(page).to have_text(
            _('No data available ' \
              'Try adjusting the filters, or creating an issue or merge request to collect more data')
          )
          expect(page).not_to have_selector('[data-testid="vsa-stage-table"]')
        end
      end

      context 'navigation' do
        it 'shows the path navigation' do
          expect(page).to have_selector(path_nav_selector)
        end

        it 'each stage will have median values' do
          stage_medians = page.all('.gl-path-button span').collect(&:text)

          expect(stage_medians).to match_array(["-"] * 4)
        end

        it 'displays the default list of stages' do
          path_nav = page.find(path_nav_selector)

          expect(path_nav).to have_content(_("Overview"))

          ['Issue', 'Code', 'Milestone Plan'].each do |item|
            string_id = "CycleAnalytics|#{item}"
            expect(path_nav).to have_content(s_(string_id))
          end
        end
      end
    end

    shared_examples 'value streams dashboard link' do
      it 'renders a link to the group dashboard' do
        expect(page).to have_selector(vsd_link_selector)

        expected_url = group_vsd_link(target_group)

        expect(page.find(vsd_link_selector)).to have_link("Value Streams Dashboard | DORA", href: expected_url)
      end
    end

    shared_examples 'date range prepopulated' do |start_date:, end_date:|
      it 'has the date range prepopulated' do
        expected_date_format = '%b %d, %Y'
        formatted_start_date = DateTime.parse(start_date).strftime(expected_date_format)
        formatted_end_date = DateTime.parse(end_date).strftime(expected_date_format)

        page.within(date_range_picker_selector) do
          expect(find('.js-daterange-picker-from input').value).to eq start_date
          expect(find('.js-daterange-picker-to input').value).to eq end_date
        end

        hover('[data-testid="vsa-task-by-type-description"]')

        expect(page.find('.tooltip')).to have_text(_("Shows issues for group '%{group_name}' from %{start_date} to %{end_date}") % { group_name: group.name, start_date: formatted_start_date, end_date: formatted_end_date })
      end
    end

    context 'without valid query parameters set' do
      before do
        create_value_stream_aggregation(group)
      end

      context 'with created_after date > created_before date' do
        before do
          visit group_analytics_cycle_analytics_path(group, created_before: '2019-11-01', created_after: '2019-12-31')
        end

        it 'displays empty text' do
          [
            'Value Stream Analytics can help you determine your team’s velocity',
            'Filter parameters are not valid. Make sure that the end date is after the start date.'
          ].each do |content|
            expect(page).to have_content(content)
          end
        end
      end

      context 'with fake parameters' do
        before do
          visit "#{group_analytics_cycle_analytics_path(group)}?beans=not-cool"

          select_value_stream(custom_value_stream_name)

          select_stage("Issue")
        end

        it 'displays an empty state' do
          expect(page).to have_text(
            _('No data available ' \
              'Try adjusting the filters, or creating an issue or merge request to collect more data')
          )
        end
      end
    end

    context 'with valid query parameters set' do
      projects_dropdown = '.js-projects-dropdown-filter'

      before do
        create_value_stream_aggregation(group)
      end

      context 'with project_ids set' do
        before do
          visit "#{group_analytics_cycle_analytics_path(group)}?project_ids[]=#{project.id}"
        end

        it 'has the projects dropdown prepopulated' do
          element = page.find(projects_dropdown)

          expect(element).to have_content project.name
        end
      end

      context 'with created_before and created_after set' do
        before do
          visit group_analytics_cycle_analytics_path(group, created_before: '2019-12-31', created_after: '2019-11-01')

          wait_for_requests
        end

        it 'shows predefined date ranges dropdown with `Custom` option selected' do
          page.within(predefined_date_ranges_dropdown_selector) do
            expect(page).to have_button('Custom')
          end
        end

        it_behaves_like 'date range prepopulated', start_date: '2019-11-01', end_date: '2019-12-31'
      end
    end

    context 'with a group' do
      let(:selected_group) { group }

      before do
        select_group_and_custom_value_stream(group, custom_value_stream_name)
      end

      it_behaves_like 'group value stream analytics'

      it_behaves_like 'has overview metrics'

      it_behaves_like 'has default filters'

      it_behaves_like 'value streams dashboard link' do
        let(:target_group) { group }
      end
    end

    context 'with a sub group' do
      let(:selected_group) { sub_group }

      before do
        select_group_and_custom_value_stream(sub_group, 'First subgroup value stream')
      end

      it_behaves_like 'group value stream analytics'

      it_behaves_like 'has overview metrics'

      it_behaves_like 'has default filters'

      it_behaves_like 'value streams dashboard link' do
        let(:target_group) { sub_group }
      end
    end
  end

  context 'with lots of data', :js, :sidekiq_inline do
    let(:issue) { create(:issue, project: project) }

    around do |example|
      freeze_time { example.run }
    end

    before do
      issue.update!(created_at: 5.days.ago.middle_of_day)
      mr.update!(created_at: issue.created_at + 1.day)
      create_cycle(user, project, issue, mr, milestone, pipeline)
      create(:labeled_issue, created_at: issue.created_at, project: create(:project, group: group), labels: [group_label1])
      create(:labeled_issue, created_at: issue.created_at + 2.days, project: create(:project, group: group), labels: [group_label2])

      issue.metrics.update!(first_mentioned_in_commit_at: mr.created_at - 5.hours, first_associated_with_milestone_at: issue.created_at + 2.days)
      mr.metrics.update!(first_deployed_to_production_at: mr.created_at + 2.hours, merged_at: mr.created_at + 1.hour)

      deploy_master(user, project, environment: 'staging')
      deploy_master(user, project)

      value_stream = create(:cycle_analytics_value_stream, namespace: group)
      Gitlab::Analytics::CycleAnalytics::DefaultStages.all.map do |params|
        group.cycle_analytics_stages.build(params.merge(value_stream: value_stream)).save!
      end
      create_value_stream_aggregation(group)

      select_group(group)
    end

    stages_with_data = [
      { title: 'Issue', description: 'Time before an issue gets scheduled', events_count: 1, time: '2 days' },
      { title: 'Code', description: 'Time until first merge request', events_count: 1, time: '5 hours' },
      { title: 'Review', description: 'Time between merge request creation and merge/close', events_count: 1, time: '1 hour' },
      { title: 'Staging', description: 'From merge request merge until deploy to production', events_count: 1, time: '1 hour' }
    ]

    stages_without_data = [
      { title: 'Plan', description: 'Time before an issue starts implementation', events_count: 0, time: "-" },
      { title: 'Test', description: 'Total test time for all commits/merges', events_count: 0, time: "-" }
    ]

    it 'each stage with events will display the stage events list when selected' do
      stages_without_data.each do |stage|
        select_stage(stage[:title])
        expect(page).not_to have_selector('[data-testid="vsa-stage-event"]')
      end

      stages_with_data.each do |stage|
        select_stage(stage[:title])
        expect(page).to have_selector('[data-testid="vsa-stage-table"]')
        expect(page.all('[data-testid="vsa-stage-event"]').length).to eq(stage[:events_count])
      end
    end

    it 'each stage will be selectable' do
      [].concat(stages_without_data, stages_with_data).each do |stage|
        select_stage(stage[:title])

        stage_name = page.find("#{path_nav_selector} .gl-path-active-item-indigo").text
        expect(stage_name).to include(stage[:title])
        expect(stage_name).to include(stage[:time])

        expect(page).to have_selector('[data-testid="vsa-duration-chart"]')
        expect(page).not_to have_selector('[data-testid="vsa-duration-overview-chart"]')
      end
    end

    it 'will not display the stage table on the overview stage' do
      expect(page).not_to have_selector('[data-testid="vsa-stage-table"]')

      select_stage("Issue")
      expect(page).to have_selector('[data-testid="vsa-stage-table"]')
    end

    it 'displays the duration overview chart on the overview stage' do
      expect(page).to have_selector('[data-testid="vsa-duration-overview-chart"]')

      expect(page).not_to have_selector('[data-testid="vsa-duration-chart"]')
    end

    it 'will have data available' do
      duration_overview_chart = find_by_testid('vsa-duration-overview-chart')
      expect(duration_overview_chart).not_to have_text(_("There is no data available. Please change your selection."))
      expect(duration_overview_chart).to have_text(s_('CycleAnalytics|Average time to completion (days)'))

      tasks_by_type_chart_content = page.find('.js-tasks-by-type-chart')
      expect(tasks_by_type_chart_content).not_to have_text(_("There is no data available. Please change your selection."))
    end

    context 'with filters applied' do
      before do
        visit group_analytics_cycle_analytics_path(group, created_before: '2019-12-31', created_after: '2019-11-01')

        wait_for_stages_to_load
      end

      it 'will filter the data' do
        duration_overview_chart = find_by_testid('vsa-duration-overview-chart')
        expect(duration_overview_chart).not_to have_text(s_('CycleAnalytics|Average time to completion (days)'))
        expect(duration_overview_chart).to have_text(
          _('No data available ' \
            'Try adjusting the filters, or creating an issue or merge request to collect more data')
        )

        tasks_by_type_chart_content = page.find('.js-tasks-by-type-chart')
        expect(tasks_by_type_chart_content).to have_text(
          _('No data available ' \
            'Try adjusting the filters, or creating an issue or merge request to collect more data')
        )
      end
    end
  end
end
