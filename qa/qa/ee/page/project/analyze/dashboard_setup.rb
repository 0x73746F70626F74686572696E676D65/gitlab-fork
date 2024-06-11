# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          class DashboardSetup < QA::Page::Base
            view 'ee/app/assets/javascripts/vue_shared/components/customizable_dashboard/customizable_dashboard.vue' do
              element 'dashboard-title-input'
              element 'dashboard-description-input'
              element 'add-visualization-button'
              element 'dashboard-save-btn'
            end

            view 'ee/app/assets/javascripts/vue_shared/components/customizable_dashboard/' \
                 'dashboard_editor/available_visualizations_drawer.vue' do
              element 'list-item-total_events', %q(:data-testid="`list-item-${visualization.slug}`") # rubocop:disable QA/ElementWithPattern -- parametrised testid
              element 'list-item-events_over_time', %q(:data-testid="`list-item-${visualization.slug}`") # rubocop:disable QA/ElementWithPattern -- parametrised testid
              element 'add-button'
            end

            view 'ee/app/assets/javascripts/vue_shared/components/' \
                 'customizable_dashboard/gridstack_wrapper.vue' do
              element 'grid-stack-panel'
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

            def check_events_over_time
              click_element 'list-item-events_over_time'
            end

            def check_visualisation(name)
              name = name.downcase.tr(' ', '_')
              click_element "list-item-#{name}"
            end

            def click_add_to_dashboard
              click_element 'add-button'
            end

            def click_save_your_dashboard
              click_element 'dashboard-save-btn'
            end

            def delete_panel(panel_index:)
              within_element_by_index('grid-stack-panel', panel_index) do
                click_element('base-dropdown-toggle')
                click_element('disclosure-dropdown-item')
              end
            end
          end
        end
      end
    end
  end
end
