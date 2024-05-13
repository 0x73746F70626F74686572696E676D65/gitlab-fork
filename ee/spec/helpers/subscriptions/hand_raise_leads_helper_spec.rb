# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Subscriptions::HandRaiseLeadsHelper, feature_category: :acquisition do
  describe '#hand_raise_modal_dataset' do
    it 'provides the expected dataset' do
      user = build_stubbed(:user)
      root_namespace = build_stubbed(:namespace)
      allow(helper).to receive(:current_user).and_return(user)
      result = {
        user: {
          namespace_id: root_namespace.id,
          user_name: user.username,
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.organization
        }.to_json,
        submit_path: subscriptions_hand_raise_leads_path
      }

      expect(helper.hand_raise_modal_dataset(root_namespace)).to eq(result)
    end
  end
end
