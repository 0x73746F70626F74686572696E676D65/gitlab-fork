# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Policies
          class PolicyEditor < QA::Page::Base
            view 'ee/app/assets/javascripts/security_orchestration/components/policy_editor/policy_type_selector.vue' do
              element 'policy-selection-wizard'
            end

            def has_policy_selection?(selector)
              has_element?(selector)
            end
          end
        end
      end
    end
  end
end
