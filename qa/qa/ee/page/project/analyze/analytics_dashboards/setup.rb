# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Analyze
          module AnalyticsDashboards
            class Setup < QA::Page::Base
              view 'ee/app/assets/javascripts/product_analytics/onboarding/' \
                   'components/instrumentation_instructions_sdk_details.vue' do
                element 'sdk-application-id-container'
                element 'sdk-host-container'
              end

              view 'ee/app/assets/javascripts/product_analytics/onboarding/' \
                   'components/providers/self_managed_provider_card.vue' do
                element 'connect-your-own-provider-btn'
              end

              view 'ee/app/assets/javascripts/product_analytics/shared/analytics_clipboard_input.vue' do
                element 'sdk-value-field'
              end

              def connect_your_own_provider
                click_element('connect-your-own-provider-btn')
              end

              def wait_for_sdk_containers
                has_element?('sdk-application-id-container', skip_finished_loading_check: true, wait: 120)
              end

              def sdk_application_id
                within_element('sdk-application-id-container') do
                  find_element('sdk-value-field')
                end
              end

              def sdk_host
                within_element('sdk-host-container') do
                  find_element('sdk-value-field')
                end
              end
            end
          end
        end
      end
    end
  end
end
