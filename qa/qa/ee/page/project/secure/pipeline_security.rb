# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class PipelineSecurity < QA::Page::Base
            view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/security_dashboard_table_row.vue' do
              element 'vulnerability-info-content'
              element 'security-finding-name-button'
              element 'security-finding-checkbox'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/vulnerability_action_buttons.vue' do
              element 'dismiss-vulnerability'
              element 'create-issue'
              element 'undo-dismiss'
              element 'more-info'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/filters.vue' do
              element 'findings-hide-dismissed-toggle'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/selection_summary_vuex.vue' do
              element 'finding-dismissal-reason'
              element 'finding-dismiss-button'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/vulnerability_report/' \
                 'vulnerability_list.vue' do
              element 'vulnerability'
              element 'vulnerability-status-content'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/vulnerability_report/' \
                 'selection_summary.vue' do
              element 'status-listbox'
              element 'change-status-button'
              element 'dismissal-reason-listbox'
              element 'change-status-comment-textbox'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/filters/status_filter.vue' do
              element 'filter-status-dropdown'
            end

            def dismiss_finding_with_reason_old_dashboard(finding_name, reason)
              check_element('security-finding-checkbox', true, finding_name: finding_name, visible: false)
              select_element('finding-dismissal-reason', reason)
              click_element('finding-dismiss-button')
            end

            def dismiss_finding_with_reason(finding_name, reason = "not_applicable")
              select_finding(finding_name)
              select_state('dismissed')
              select_dismissal_reason(reason)
              fill_element('change-status-comment-textbox', "E2E Test")
              click_element('change-status-button')
            end

            def select_finding(finding_name)
              click_element('vulnerability-status-content', status_description: finding_name)
            end

            def select_state(state)
              retry_until(max_attempts: 3, sleep_interval: 2, message: "Setting status and comment") do
                click_element('status-listbox', wait: 5)
                click_element(:"listbox-item-#{state}", wait: 5)
                has_element?('change-status-comment-textbox', wait: 2)
              end
            end

            def select_dismissal_reason(reason)
              click_element('dismissal-reason-listbox')
              click_element(:"listbox-item-#{reason}")
            end

            def select_status(status)
              click_element('filter-status-dropdown')
              click_element(:"listbox-item-#{status}")
              click_element('filter-status-dropdown')
            end

            def toggle_hide_dismissed_off
              toggle_hide_dismissed("off")
            end

            def toggle_hide_dismissed_on
              toggle_hide_dismissed("on")
            end

            def toggle_hide_dismissed(toggle_to)
              within_element('findings-hide-dismissed-toggle') do
                toggle = find('button.gl-toggle')
                checked = toggle[:class].include?('is-checked')
                toggle.click if (checked && toggle_to == "off") || (!checked && toggle_to == "on")
              end
            end

            def undo_dismiss_button_present?(finding_name)
              has_element?('undo-dismiss', finding_name: finding_name)
            end

            def create_issue_old_dashboard(finding_name)
              click_element('create-issue', QA::Page::Project::Issue::Show, finding_name: finding_name)
            end

            def create_issue(finding_name)
              click_finding(finding_name)
              click_element('create-issue-button')
            end

            def click_finding(finding_name)
              click_element('vulnerability', vulnerability_description: finding_name)
              wait_for_requests
            end

            def expand_security_finding(finding_name)
              click_element('more-info', finding_name: finding_name)
            end
          end
        end
      end
    end
  end
end
