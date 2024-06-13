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

  describe '#discover_page_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'trial_discover_page',
        cta_tracking: {
          action: 'click_contact_sales',
          label: 'trial_expired'
        }.to_json,
        button_attributes: {
          variant: 'confirm',
          category: 'secondary',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }

      expect(helper.discover_page_hand_raise_lead_data(build_stubbed(:group))).to eq(result)
    end
  end

  describe '#free_plan_billing_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'billing-group',
        button_text: s_("BillingPlans|Talk to an expert"),
        cta_tracking: { action: 'click_button' }.to_json,
        button_attributes: {
          category: 'secondary',
          class: 'gl-vertical-align-text-bottom'
        }.to_json
      }

      expect(helper.free_plan_billing_hand_raise_lead_data).to eq(result)
    end
  end

  describe '#code_suggestions_billing_card_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Duo Pro Add-On',
        cta_tracking: {
          action: 'click_button',
          label: 'code_suggestions_hand_raise_lead_form'
        }.to_json,
        button_attributes: {
          'data-testid': 'code-suggestions-hand-raise-lead-button',
          category: 'tertiary',
          variant: 'confirm'
        }.to_json
      }

      expect(helper.code_suggestions_billing_card_hand_raise_lead_data).to eq(result)
    end
  end

  describe '#billing_action_hand_raise_lead_data' do
    it 'provides the expected dataset' do
      result = {
        glm_content: 'billing-group',
        cta_tracking: { action: 'click_link', property: 'code' }.to_json,
        button_attributes: {}.to_json
      }

      expect(helper.billing_action_hand_raise_lead_data('code')).to eq(result)
    end
  end

  describe 'discover_duo_pro_hand_raise_lead_data' do
    let_it_be(:namespace) { build_stubbed(:group) }

    it 'provides the expected dataset' do
      result = {
        namespace_id: namespace.id,
        glm_content: 'discover-duo-pro',
        cta_tracking: {
          action: 'click_contact_sales',
          label: 'duo_pro_active_trial'
        }.to_json,
        button_attributes: {
          'data-testid': 'discover-duo-pro-hand-raise-lead-button',
          category: 'secondary',
          variant: 'confirm'
        }.to_json
      }

      expect(helper.discover_duo_pro_hand_raise_lead_data(namespace)).to eq(result)
    end
  end
end
