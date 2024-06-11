# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          class VisualizationSetup < QA::Page::Base
            include ::QA::Page::Component::Dropdown

            view 'ee/app/assets/javascripts/analytics/analytics_dashboards/' \
              'components/analytics_visualization_designer.vue' do
              element 'visualization-title-input'
              element 'visualization-type-dropdown'
              element 'visualization-save-btn'
            end

            view 'ee/app/assets/javascripts/analytics/analytics_dashboards/components/visualization_designer/' \
              'selectors/product_analytics/measure_selector.vue' do
              element 'events-button'
              element 'events-all-button'
            end

            def set_visualization_title(title)
              fill_element 'visualization-title-input', title
            end

            def select_visualization_type(type)
              click_element 'visualization-type-dropdown'
              select_item type, css: 'li.gl-dropdown-item'
            end

            def choose_events
              within_element 'events-button' do
                click_element '.btn-confirm'
              end
            end

            def choose_all_events_compared
              within_element 'events-all-button' do
                click_element '.btn-confirm'
              end
            end

            def click_save_your_visualization
              click_element 'visualization-save-btn'
            end
          end
        end
      end
    end
  end
end
