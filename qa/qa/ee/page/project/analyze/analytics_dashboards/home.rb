# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          module AnalyticsDashboards
            class Home < QA::Page::Base
              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/list/dashboard_list_item.vue' do
                element 'dashboard-list-item'
                element 'dashboard-router-link'
                element 'dashboard-errors-badge'
              end

              view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/dashboards_list.vue' do
                element 'configure-dashboard-container'
                element 'new-dashboard-button'
                element 'visualization-designer-button'
              end

              def wait_for_dashboards_list
                has_element?('dashboard-router-link', wait: 120)
              end

              def dashboards_list
                all_elements('dashboard-router-link', minimum: 2)
              end

              def open_audience_dashboard
                dashboards_list[0].click
              end

              def open_behavior_dashboard
                dashboards_list[1].click
              end

              def click_configure_dashboard_project
                within_element('configure-dashboard-container') do
                  click_element('.btn-confirm')
                end
              end

              def click_visualization_designer_button
                click_element('visualization-designer-button')
              end

              def click_new_dashboard_button
                click_element('new-dashboard-button')
              end

              def list_item_has_errors_badge?(list_item_index:, wait: 1)
                within_element_by_index('dashboard-list-item', list_item_index) do
                  has_element?('dashboard-errors-badge', wait: wait)
                end
              end
            end
          end
        end
      end
    end
  end
end
