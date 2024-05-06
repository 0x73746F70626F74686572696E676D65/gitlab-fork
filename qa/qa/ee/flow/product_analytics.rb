# frozen_string_literal: true

module QA
  module EE
    module Flow
      module ProductAnalytics
        class << self
          # Set up and activate Product Analytics for a specific project
          # @note Product Analytics env vars in [Runtime::Env] must be set
          # @param [Resource::Project] project - the project for which to enable product analytics
          # @return [void]
          def activate(project)
            unless required_vars_set?
              raise 'Cannot activate product analytics. ' \
                    'PA_CONFIGURATOR_URL, PA_COLLECTOR_HOST, ' \
                    'PA_CUBE_API_URL, PA_CUBE_API_KEY ' \
                    'env variables must be set.'
            end

            project.visit!
            QA::Page::Project::Menu.perform(&:go_to_analytics_settings)
            EE::Page::Project::Settings::Analytics.perform do |analytics_settings|
              analytics_settings.expand_data_sources do |data_sources|
                data_sources.fill_snowplow_configurator(QA::Runtime::Env.pa_configurator_url)
                data_sources.fill_collector_host(QA::Runtime::Env.pa_collector_host)
                data_sources.fill_cube_api_url(QA::Runtime::Env.pa_cube_api_url)
                data_sources.fill_cube_api_key(QA::Runtime::Env.pa_cube_api_key)
                data_sources.save_changes
              end
            end

            QA::Page::Project::Menu.perform(&:go_to_analytics_dashboards)
            EE::Page::Project::Analyze::AnalyticsDashboards::Initial.perform(&:click_set_up)
            EE::Page::Project::Analyze::AnalyticsDashboards::Setup.perform(&:connect_your_own_provider)
          end

          private

          def required_vars_set?
            !QA::Runtime::Env.pa_configurator_url.nil? && !QA::Runtime::Env.pa_collector_host.nil? &&
              !QA::Runtime::Env.pa_cube_api_url.nil? && !QA::Runtime::Env.pa_cube_api_key.nil?
          end
        end
      end
    end
  end
end
