# frozen_string_literal: true

module QA
  RSpec.describe 'Monitor' do
    describe(
      'Product Analytics',
      only: { condition: -> { ENV["CI_PROJECT_PATH_SLUG"].include? "product-analytics-devkit" } },
      product_group: :product_analytics
    ) do
      let!(:sandbox_group) { create(:sandbox, path: "gitlab-qa-product-analytics") }
      let!(:group) { create(:group, name: "product-analytics-g-#{SecureRandom.hex(8)}", sandbox: sandbox_group) }
      let!(:project) do
        create(:project, :with_readme, name: "project-analytics-p-#{SecureRandom.hex(8)}", group: group)
      end

      let(:sdk_host) { Runtime::Env.pa_collector_host }

      let(:custom_dashboard_title) { 'My New Custom Dashboard' }
      let(:custom_visualization_title) { 'Events amount custom' }
      let(:custom_visualization_type) { 'Data table' }

      before do
        Flow::Login.sign_in
        EE::Flow::ProductAnalytics.activate(project)
      end

      it 'custom visualisation can be created and displayed on a dashboard',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/466572' do
        sdk_app_id = 0

        EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform do |analytics_dashboards_setup|
          analytics_dashboards_setup.wait_for_sdk_containers
          sdk_app_id = analytics_dashboards_setup.sdk_application_id.value
        end

        Vendor::Snowplow::ProductAnalytics::Event.perform do |event|
          payload = event.build_payload(sdk_app_id)
          event.send(sdk_host, payload)
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          analytics_dashboards.wait_for_dashboards_list
          analytics_dashboards.click_configure_dashboard_project
        end

        EE::Page::Project::Settings::Analytics.perform do |analytics_settings|
          analytics_settings.set_dashboards_configuration_project(project)
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform(&:click_visualization_designer_button)

        EE::Page::Project::Analyze::VisualizationSetup.perform do |visualization|
          visualization.set_visualization_title(custom_visualization_title)
          visualization.select_visualization_type(custom_visualization_type)
          visualization.choose_measure_all_events
          visualization.click_save_your_visualization
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform(&:click_new_dashboard_button)

        EE::Page::Project::Analyze::DashboardSetup.perform do |your_dashboard|
          your_dashboard.set_dashboard_title(custom_dashboard_title)
          your_dashboard.click_add_visualisation
          your_dashboard.check_visualisation(custom_visualization_title)
          your_dashboard.click_add_to_dashboard
          your_dashboard.click_save_your_dashboard
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          analytics_dashboards.click_dashboard_list_item(custom_dashboard_title)
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          panels = dashboard.panels
          aggregate_failures 'test custom visualization' do
            expect(panels.count).to equal(1)
            expect(dashboard.panel_title(panel_index: 0)).to eq(custom_visualization_title)
            expect(dashboard.table_value(panel_index: 0, cell_index: 0)).to equal(1)
          end
        end
      end
    end
  end
end
