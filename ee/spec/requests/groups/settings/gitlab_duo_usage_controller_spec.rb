# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuoUsageController, type: :request, feature_category: :duo_chat do
  let(:admin) { create(:admin) }
  let_it_be(:group) { create(:group) }

  subject(:get_index) { get group_settings_gitlab_duo_usage_index_path(group) }

  before do
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    sign_in(admin)
  end

  context "when gitlab_duo_usage_menu_item feature flag is disabled" do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_feature_flags(gitlab_duo_usage_menu_item: false)
    end

    it "renders 404" do
      get_index

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context "when show_gitlab_duo_usage_app? returns false" do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    it "renders 404" do
      get_index

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context "when show_gitlab_duo_usage_app? returns true and gitlab_duo_usage_menu_item feature flag is enabled" do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it "renders index with 200 status code" do
      get_index

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end
end
