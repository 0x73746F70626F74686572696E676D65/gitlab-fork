# frozen_string_literal: true

module QA
  module EE
    module Page
      module Trials
        class New < QA::Page::Base
          view 'ee/app/assets/javascripts/trials/components/trial_create_lead_form.vue' do
            element 'first-name-field'
            element 'last-name-field'
            element 'company-name-field'
            element 'company-size-dropdown'
            element 'phone-number-field'
            element 'continue-button'
          end

          view 'ee/app/assets/javascripts/trials/components/country_or_region_selector.vue' do
            element 'country-dropdown'
            element 'state-dropdown'
          end

          def self.path
            '/-/trials/new'
          end

          # Fill in the customer trial information
          # @param [Hash] customer The customer trial information
          # @option customer [String] :company_name The name of the company
          # @option customer [String] :company_size The size of the company
          # @option customer [String] :phone_number The phone number of the company
          # @option customer [String] :country The country of the company
          # @option customer [String] :state The state of the company
          def fill_in_customer_trial_info(customer)
            fill_element('company-name-field', customer[:company_name])
            select_element('company-size-dropdown', customer[:company_size])
            select_element('country-dropdown', customer[:country])
            fill_element('phone-number-field', customer[:phone_number])
            select_element('state-dropdown', customer[:state])
          end

          def click_continue_button
            click_element('continue-button')
          end
        end
      end
    end
  end
end
