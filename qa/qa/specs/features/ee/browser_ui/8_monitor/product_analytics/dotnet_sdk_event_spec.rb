# frozen_string_literal: true

module QA
  RSpec.describe 'Monitor' do
    # rubocop:disable RSpec/InstanceVariable -- needed to shut down sample app container in after hook.
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

      before do
        Flow::Login.sign_in
      end

      after do
        @sample_app.remove!
      end

      it 'displays events from dotnet sdk',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/461078' do
        sdk_app_id = 0

        EE::Flow::ProductAnalytics.activate(project)

        EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform do |analytics_dashboards_setup|
          analytics_dashboards_setup.wait_for_sdk_containers
          sdk_app_id = analytics_dashboards_setup.sdk_application_id.value
        end

        @sample_app = Service::DockerRun::ProductAnalytics::DotnetSdkApp.new(sdk_host, sdk_app_id)
        @sample_app.pull
        # register! in this case will trigger an event from .NET SDK app
        # because it sends GET request via curl to determine if the app is up.
        # GET request for this specific app triggers analytics event.
        @sample_app.register!

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          analytics_dashboards.wait_for_dashboards_list
          analytics_dashboards.open_behavior_dashboard
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          aggregate_failures 'check total events' do
            expect(dashboard.panel(panel_index: 1)).to have_content('Total events')
            expect(dashboard.panel_value_content(panel_index: 1)).to eq(1)
          end
        end
      end
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
