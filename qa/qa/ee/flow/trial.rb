# frozen_string_literal: true

module QA
  module EE
    module Flow
      module Trial
        extend self

        CUSTOMER_TRIAL_INFO = {
          company_name: 'QA Test Company',
          company_size: '500 - 1,999',
          phone_number: '555-555-5555',
          country: 'United States of America',
          state: 'California'
        }.freeze

        def register_for_trial(group: nil)
          EE::Page::Trials::New.perform do |new|
            new.fill_in_customer_trial_info(CUSTOMER_TRIAL_INFO)
            new.click_continue_button
          end

          return unless group

          EE::Page::Trials::Select.perform do |select|
            select.trial_for = group.path
            select.click_trial_for_company_option
            select.click_start_your_free_trial_button
          end
        end
      end
    end
  end
end
