# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module SecureReport
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'ee/app/assets/javascripts/security_dashboard/components/security_dashboard_table.vue' do
                element 'security-report-content'
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/shared/filters/activity_filter.vue' do
                element 'filter-activity-dropdown'
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/shared/filters/status_filter.vue' do
                element 'filter-status-dropdown'
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/
                    shared/vulnerability_report/vulnerability_list.vue' do
                element 'vulnerability-status-content'
              end
            end
          end

          def filter_report_type(report)
            wait_until(max_duration: 20, sleep_interval: 3, message: "Wait for tool dropdown to appear") do
              has_element?('filter-tool-dropdown')
            end
            click_element('filter-tool-dropdown')

            find(status_listbox_item_selector(report)).click

            # Click the dropdown to close the modal and ensure it isn't open if this function is called again
            click_element('filter-tool-dropdown')
          end

          def status_listbox_item_selector(report)
            "[data-testid='listbox-item-#{report.upcase.tr(" ", "_")}']"
          end

          def filter_by_status(statuses)
            if has_element?('group-by-new-feature')
              within_element('group-by-new-feature') do
                click_element('close-button')
              end
            end

            if has_element?('filtered-search-token', wait: 10)
              filter_by_status_new(statuses)
            else
              filter_by_status_old(statuses)
            end

            state = statuses_list(statuses).map { |item| "state=#{item}" }.join("&")
            raise 'Status unchanged in the URL' unless page.current_url.downcase.include?(state)
          end

          def filter_by_status_old(statuses)
            wait_until(max_duration: 30, message: "Waiting for status dropdown element to appear") do
              has_element?('filter-status-dropdown')
            end
            # Retry on exception to avoid ElementNotFound errors when clicks are sent too fast for the UI to update
            retry_on_exception(sleep_interval: 2, message: "Retrying status click until current url matches state") do
              find(status_dropdown_button_selector, wait: 5).click
              find(status_item_selector('ALL')).click
              statuses_list(statuses).each do |status|
                find(status_item_selector(status)).click
                wait_for_requests # It takes a moment to update the page after changing selections
              end
              find(status_dropdown_button_selector, wait: 5).click
            end
          end

          def filter_by_status_new(statuses)
            click_element('clear-icon')
            click_element('filtered-search-token-segment')
            click_link('Status')
            click_link('All statuses')
            statuses_list_advanced_filter(statuses).each do |status|
              click_link(status) unless status == 'Dismissed'
              click_link('All dismissal reasons') if status == 'Dismissed'
              wait_for_requests
            end
            click_element('search-button')
            click_element('search-button') # second click removes the dynamic dropdown
          end

          def statuses_list(statuses)
            statuses.map do |status|
              case status
              when /all/i
                'all'
              when /needs triage/i
                'detected'
              else
                status
              end
            end
          end

          def statuses_list_advanced_filter(statuses)
            statuses.map do |status|
              case status
              when /all/i
                'All statuses'
              when /needs triage/i
                'Needs triage'
              else
                status.capitalize
              end
            end
          end

          def status_dropdown_button_selector
            "[data-testid='filter-status-dropdown'] > button"
          end

          def status_item_selector(status)
            "[data-testid='listbox-item-#{status.upcase}']"
          end

          def filter_by_activity(activity_name)
            find(activity_dropdown_button_selector, wait: 5).click
            find(activity_item_selector(activity_name)).click
          end

          def activity_dropdown_button_selector
            "[data-testid='filter-activity-dropdown'] > button"
          end

          def activity_item_selector(activity_name)
            "[data-testid='listbox-item-#{activity_name}']"
          end

          def has_vulnerability?(name)
            retry_until(reload: true, sleep_interval: 10, max_attempts: 6, message: "Retry for vulnerability text") do
              has_element?(:vulnerability, text: name)
            end
          end

          def has_vulnerability_info_content?(name)
            retry_until(reload: true, sleep_interval: 2, max_attempts: 2, message: 'Finding "Security Finding" text') do
              has_element?('vulnerability-info-content', text: name,
                wait: 1) || has_element?('vulnerability', text: name, wait: 1)
            end
          end

          def has_status?(status, vulnerability_name)
            retry_until(reload: true, sleep_interval: 3, raise_on_failure: false) do
              # Capitalizing first letter in each word to account for "Needs Triage" state
              has_element?(
                'vulnerability-status-content',
                status_description: vulnerability_name,
                text: status.split.map(&:capitalize).join(' ').to_s
              )
            end
          end
        end
      end
    end
  end
end
