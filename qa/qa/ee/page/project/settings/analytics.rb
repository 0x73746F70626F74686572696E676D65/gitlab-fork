# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          class Analytics < QA::Page::Base
            include QA::Page::Settings::Common

            view 'ee/app/views/projects/settings/analytics/_data_sources.html.haml' do
              element 'data-sources-content'
            end

            view 'ee/app/views/projects/settings/analytics/_custom_dashboard_projects.html.haml' do
              element 'analytics-dashboards-settings'
            end

            def expand_data_sources(&block)
              expand_content('data-sources-content') do
                DataSources.perform(&block)
              end
            end

            def set_dashboards_configuration_project(project)
              within_element('analytics-dashboards-settings') do
                click_element('base-dropdown-toggle')
                wait_for_requests
                find('.gl-listbox-search-input').set(project.name)
                click_element("listbox-item-#{project.id}")
                click_element('.btn-confirm')
              end
            end
          end
        end
      end
    end
  end
end
