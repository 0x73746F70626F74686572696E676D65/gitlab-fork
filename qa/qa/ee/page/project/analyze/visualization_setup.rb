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

            def set_visualization_title(title)
              fill_element 'visualization-title-input', title
            end

            def select_visualization_type(type)
              click_element 'visualization-type-dropdown'
              find('option', text: type).click
            end

            def choose_measure_all_events
              within_element 'visualization-filtered-search' do
                click_element 'filtered-search-term'
                click_link('Measure')
                click_link('Tracked Events Count')
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
