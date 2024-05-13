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
  end
end
