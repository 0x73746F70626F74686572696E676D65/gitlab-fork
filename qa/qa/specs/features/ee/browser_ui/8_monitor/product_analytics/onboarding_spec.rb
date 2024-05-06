# frozen_string_literal: true

module QA
  RSpec.describe 'Monitor' do
    describe(
      'Product Analytics',
      only: { condition: -> { ENV["CI_PROJECT_PATH_SLUG"].include? "product-analytics-devkit" } },
      product_group: :product_analytics
    ) do
      let!(:sandbox_group) { create(:sandbox, path: "gitlab-qa-product-analytics-2") }
      let!(:group) { create(:group, name: "product-analytics-g-#{SecureRandom.hex(8)}", sandbox: sandbox_group) }
      let!(:project) do
        create(:project, :with_readme, name: "project-analytics-p-#{SecureRandom.hex(8)}", group: group)
      end

      let(:sdk_host) { Runtime::Env.pa_collector_host }

      before do
        Flow::Login.sign_in
      end

      it 'can be onboarded', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/432598' do
        sdk_app_id = 0

        EE::Flow::ProductAnalytics.activate(project)

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
          analytics_dashboards.open_audience_dashboard
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          panels = dashboard.audience_dashboard_panels
          aggregate_failures 'test audience dashboard' do
            expect(panels.count).to equal(9)
            expect(panels[0]).to have_content('Total Unique Users')
            expect(dashboard.panel_value_content(panel_index: 0)).to equal(1)
          end
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform(&:open_behavior_dashboard)

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          panels = dashboard.behavior_dashboard_panels
          aggregate_failures 'test behavior dashboard' do
            expect(panels.count).to equal(5)
            expect(panels[1].text).to have_content('Total events')
            expect(dashboard.panel_value_content(panel_index: 1)).to equal(1)
          end
        end
      end
    end
  end
end
