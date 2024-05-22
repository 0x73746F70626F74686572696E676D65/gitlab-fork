# frozen_string_literal: true

module Subscriptions
  module HandRaiseLeadsHelper
    def hand_raise_modal_dataset(root_namespace)
      {
        user: {
          namespace_id: root_namespace.id,
          user_name: current_user.username,
          first_name: current_user.first_name,
          last_name: current_user.last_name,
          company_name: current_user.organization
        }.to_json,
        submit_path: subscriptions_hand_raise_leads_path
      }
    end

    def discover_page_hand_raise_lead_data(group)
      {
        glm_content: 'trial_discover_page',
        cta_tracking: {
          track_action: 'click_contact_sales',
          track_label: group_trial_status(group),
          track_experiment: :trial_discover_page
        }.to_json,
        button_attributes: {
          variant: 'confirm',
          category: 'secondary',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }
    end
  end
end
