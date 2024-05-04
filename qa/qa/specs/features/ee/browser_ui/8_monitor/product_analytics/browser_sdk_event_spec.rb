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

      it 'displays events from browser sdk',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/451196' do
        sdk_app_id = 0

        project.visit!
        Page::Project::Menu.perform(&:go_to_analytics_settings)
        EE::Page::Project::Settings::Analytics.perform do |analytics_settings|
          analytics_settings.expand_data_sources do |data_sources|
            data_sources.fill_snowplow_configurator(Runtime::Env.pa_configurator_url)
            data_sources.fill_collector_host(Runtime::Env.pa_collector_host)
            data_sources.fill_cube_api_url(Runtime::Env.pa_cube_api_url)
            data_sources.fill_cube_api_key(Runtime::Env.pa_cube_api_key)
            data_sources.save_changes
          end
        end

        Page::Project::Menu.perform(&:go_to_analytics_dashboards)
        EE::Page::Project::Analyze::AnalyticsDashboards::Initial.perform(&:click_set_up)
        EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform(&:connect_your_own_provider)

        EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform do |analytics_dashboards_setup|
          analytics_dashboards_setup.wait_for_sdk_containers
          sdk_app_id = analytics_dashboards_setup.sdk_application_id.value
        end

        @sample_app = Service::DockerRun::ProductAnalytics::BrowserSdkApp.new(sdk_host, sdk_app_id)
        @sample_app.pull
        @sample_app.register!

        click_button_on_sample_app(@sample_app.host_name, @sample_app.port)

        EE::Page::Project::Analyze::AnalyticsDashboards::Home.perform do |analytics_dashboards|
          analytics_dashboards.wait_for_dashboards_list
          analytics_dashboards.open_behavior_dashboard
        end

        EE::Page::Project::Analyze::AnalyticsDashboards::Dashboard.perform do |dashboard|
          aggregate_failures 'check total events' do
            expect(dashboard.panel(panel_index: 1)).to have_content('Total events')
            expect(dashboard.panel_value_content(panel_index: 1)).to eq(2)
          end
        end
      end
    end

    def click_button_on_sample_app(host_name, port)
      new_window = open_new_window
      within_window new_window do
        visit("http://#{host_name}:#{port}")
        find('.accept-btn').click
        QA::Runtime::Logger.info('Accepted cookies on sample app')
        find('#testClickBtn').click
        QA::Runtime::Logger.info('Clicked "Track event" button on sample app')
      end
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
