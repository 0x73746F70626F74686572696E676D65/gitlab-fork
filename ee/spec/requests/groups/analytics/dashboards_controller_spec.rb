# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Analytics::DashboardsController, feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:user) do
    create(:user).tap do |user|
      group.add_reporter(user)
      another_group.add_reporter(user)
    end
  end

  shared_examples 'forbidden response' do
    it 'returns forbidden response' do
      request

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  shared_examples 'built in value streams dashboard' do
    it 'accepts a `query` params' do
      project = projects.first

      get build_dashboard_path(
        value_streams_dashboard_group_analytics_dashboards_path(group),
        [another_group, subgroup, project]
      )

      expect(response).to be_successful

      expect(response.body.include?("data-namespaces")).to be_truthy
      expect(response.body).not_to include(parsed_response(another_group, false))
      expect(response.body).to include(parsed_response(subgroup, false))
      expect(response.body).to include(parsed_response(project))
    end

    it 'returns projects in a subgroup' do
      first_parent_project = projects.first
      params = [].concat(subgroup_projects, [subgroup], [first_parent_project])

      get build_dashboard_path(value_streams_dashboard_group_analytics_dashboards_path(group), params)

      expect(response).to be_successful
      expect(response.body).to include(parsed_response(subgroup, false))
      expect(response.body).to include(parsed_response(first_parent_project))

      subgroup_projects.each do |project|
        expect(response.body).to include(parsed_response(project))
      end
    end

    def parsed_response(namespace, is_project = true)
      json = { name: namespace.name, full_path: namespace.full_path, is_project: is_project }.to_json
      HTMLEntities.new.encode(json)
    end

    def build_dashboard_path(path, namespaces)
      "#{path}?query=#{namespaces.map(&:full_path).join(',')}"
    end
  end

  shared_examples 'shared analytics value streams dashboard' do
    it 'passes pointer_project if it has been configured' do
      analytics_dashboards_pointer
      request

      expect(response).to be_successful

      expect(js_list_app_attributes['data-dashboard-project'].value).to eq({
        id: analytics_dashboards_pointer.target_project.id,
        full_path: analytics_dashboards_pointer.target_project.full_path,
        name: analytics_dashboards_pointer.target_project.name,
        default_branch: analytics_dashboards_pointer.target_project.default_branch
      }.to_json)
    end

    it 'loads the available visualizations' do
      request

      expect(response).to be_successful
      expect(js_list_app_attributes).to include('data-available-visualizations')
    end

    it 'passes data_source_clickhouse to data attributes' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).to include('data-data-source-clickhouse')
    end

    it 'passes topics-explore-projects-path to data attributes' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).to include('data-topics-explore-projects-path')
    end

    context 'when project_id outside of the group hierarchy was set' do
      it 'does not pass the project pointer' do
        project_outside_the_hierarchy = create(:project)
        analytics_dashboards_pointer.update_column(:target_project_id, project_outside_the_hierarchy.id)

        request

        expect(response).to be_successful

        expect(js_list_app_attributes).not_to include('data-dashboard-project')
      end
    end

    it 'does not pass pointer_project if the configured project is missing' do
      analytics_dashboards_pointer.target_project.destroy!
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).not_to include('data-dashboard-project')
    end

    it 'does not pass pointer_project if it was not configured' do
      request

      expect(response).to be_successful

      expect(js_list_app_attributes).not_to include('data-dashboard-project')
    end
  end

  shared_examples 'sets data source instance variable correctly' do
    context 'when clickhouse data collection is enabled for group' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
      end

      specify do
        request

        expect(assigns[:data_source_clickhouse]).to eq(true)
      end
    end

    context 'when clickhouse data collection is not enabled' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
      end

      specify do
        request

        expect(assigns[:data_source_clickhouse]).to eq(false)
      end
    end
  end

  describe 'GET index' do
    let(:request) { get(group_analytics_dashboards_path(group)) }
    let_it_be(:projects, refind: true) { create_list(:project, 4, :public, group: group) }
    let(:analytics_dashboards_pointer) do
      create(:analytics_dashboards_pointer, namespace: group, target_project: projects.first)
    end

    before do
      stub_licensed_features(group_level_analytics_dashboard: true)
    end

    context 'when user is not logged in' do
      it 'redirects the user to the login page' do
        request

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when user is logged in' do
      before do
        sign_in(user)
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it_behaves_like 'forbidden response'
      end

      context 'when the license is available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: true)
        end

        it 'succeeds' do
          request

          expect(response).to be_successful
        end

        it_behaves_like 'sets data source instance variable correctly'

        context 'when group_analytics_dashboard_dynamic_vsd feature flag is disabled' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:subgroup_projects) { create_list(:project, 2, :public, group: subgroup) }

          before do
            stub_feature_flags(group_analytics_dashboard_dynamic_vsd: false)
          end

          it_behaves_like 'built in value streams dashboard'
        end

        context 'when group_analytics_dashboard_dynamic_vsd feature flag is enabled' do
          it_behaves_like 'shared analytics value streams dashboard'
        end
      end
    end
  end

  describe 'GET value_streams_dashboard' do
    let(:request) { get(value_streams_dashboard_group_analytics_dashboards_path(group)) }

    context 'when user is not logged in' do
      before do
        stub_licensed_features(group_level_analytics_dashboard: true)
      end

      it 'redirects the user to the login page' do
        request

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when user is not authorized' do
      let_it_be(:user) { create(:user) }

      before do
        stub_licensed_features(group_level_analytics_dashboard: true)

        sign_in(user)
      end

      it_behaves_like 'forbidden response'
    end

    context 'when user is logged in' do
      before do
        sign_in(user)
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(group_level_analytics_dashboard: false)
        end

        it_behaves_like 'forbidden response'
      end

      context 'when the license is available' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:projects, refind: true) { create_list(:project, 4, :public, group: group) }
        let_it_be(:subgroup_projects) { create_list(:project, 2, :public, group: subgroup) }
        let(:analytics_dashboards_pointer) do
          create(:analytics_dashboards_pointer, namespace: group, target_project: projects.first)
        end

        before do
          stub_licensed_features(group_level_analytics_dashboard: true)
        end

        it 'succeeds' do
          request

          expect(response).to be_successful
        end

        it_behaves_like 'sets data source instance variable correctly'

        context 'when group_analytics_dashboard_dynamic_vsd feature flag is enabled' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:subgroup_projects) { create_list(:project, 2, :public, group: subgroup) }

          it_behaves_like 'shared analytics value streams dashboard'
        end

        context 'when group_analytics_dashboard_dynamic_vsd feature flag is disabled' do
          before do
            stub_feature_flags(group_analytics_dashboard_dynamic_vsd: false)
          end

          it_behaves_like 'built in value streams dashboard'

          it 'passes pointer_project if it has been configured' do
            analytics_dashboards_pointer
            request

            expect(response).to be_successful

            expect(js_app_attributes['data-pointer-project'].value).to eq({
              id: analytics_dashboards_pointer.target_project.id,
              name: analytics_dashboards_pointer.target_project.name,
              full_path: analytics_dashboards_pointer.target_project.full_path
            }.to_json)
          end

          it 'passes data_source_clickhouse to data attributes' do
            request

            expect(response).to be_successful

            expect(js_app_attributes).to include('data-data-source-clickhouse')
          end

          context 'when project_id outside of the group hierarchy was set' do
            it 'does not pass the project pointer' do
              project_outside_the_hierarchy = create(:project)
              analytics_dashboards_pointer.update_column(:target_project_id, project_outside_the_hierarchy.id)

              request

              expect(response).to be_successful

              expect(js_app_attributes).not_to include('data-pointer-project')
            end
          end

          it 'does not pass pointer_project if the configured project is missing' do
            analytics_dashboards_pointer.target_project.destroy!
            request

            expect(response).to be_successful

            expect(js_app_attributes).not_to include('data-pointer-project')
          end

          it 'does not pass pointer_project if it was not configured' do
            request

            expect(response).to be_successful

            expect(js_app_attributes).not_to include('data-pointer-project')
          end
        end
      end
    end
  end

  def js_app_attributes
    Nokogiri::HTML.parse(response.body).at_css('div#js-analytics-dashboards-app').attributes
  end

  def js_list_app_attributes
    Nokogiri::HTML.parse(response.body).at_css('div#js-analytics-dashboards-list-app').attributes
  end
end

RSpec.describe Groups::Analytics::DashboardsController, type: :controller, feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) do
    create(:user).tap do |user|
      group.add_reporter(user)
    end
  end

  before do
    stub_licensed_features(group_level_analytics_dashboard: true)

    sign_in(user)
  end

  it_behaves_like 'tracking unique visits', :value_streams_dashboard do
    let(:request_params) { { group_id: group.to_param } }
    let(:target_id) { 'g_metrics_comparison_page' }
  end

  it_behaves_like 'Snowplow event tracking with RedisHLL context' do
    subject { get :value_streams_dashboard, params: { group_id: group.to_param }, format: :html }

    let(:category) { described_class.name }
    let(:action) { 'perform_analytics_usage_action' }
    let(:label) { 'redis_hll_counters.analytics.g_metrics_comparison_page_monthly' }
    let(:property) { 'g_metrics_comparison_page' }
    let(:namespace) { group }
    let(:project) { nil }
  end
end
