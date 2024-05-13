# frozen_string_literal: true

module QA
  module EE
    module Page
      module Alert
        module FreeTrial
          extend QA::Page::PageConcern

          def self.included(base)
            super

            base.view 'ee/app/views/subscriptions/trials/_alert.html.haml' do
              element 'trial-activated-content'
            end
          end

          def has_trial_activated_alert?
            within_element('trial-activated-content') do
              has_text?('Congratulations, your free trial is activated')
            end
          end
        end
      end
    end
  end
end
