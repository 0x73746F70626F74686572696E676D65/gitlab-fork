# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          class CreateYourDashboard < QA::Page::Base
            view 'ee/app/assets/javascripts/vue_shared/components/customizable_dashboard/customizable_dashboard.vue' do
              element 'dashboard-title-input'
              element 'dashboard-description-input'
              element 'add-visualization-button'
              element 'dashboard-save-btn'
            end

            view 'ee/app/assets/javascripts/vue_shared/components/customizable_dashboard/' \
                 'dashboard_editor/available_visualizations_drawer.vue' do
              element 'list-item-total_events', %q(:data-testid="`list-item-${visualization.slug}`") # rubocop:disable QA/ElementWithPattern -- parametrised testid
              element 'add-button'
            end

            def set_dashboard_title(title)
              fill_element 'dashboard-title-input', title
            end

            def set_dashboard_description(description)
              fill_element 'dashboard-description-input', description
            end

            def click_add_visualisation
              click_element 'add-visualization-button'
            end

            def check_total_events
              click_element 'list-item-total_events'
            end

            def click_add_to_dashboard
              click_element 'add-button'
            end

            def click_save_your_dashboard
              click_element 'dashboard-save-btn'
            end
          end
        end
      end
    end
  end
end
