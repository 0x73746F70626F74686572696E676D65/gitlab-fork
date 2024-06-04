# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminSettingsMenu, feature_category: :navigation do
  let_it_be(:user) { build(:user, :admin) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  describe 'Menu Items' do
    subject(:items) { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    describe 'Analytics menu', feature_category: :product_analytics_data_management do
      let(:item_id) { :admin_analytics }

      context 'when product_analytics feature is licensed' do
        before do
          stub_licensed_features(product_analytics: true)
        end

        it { is_expected.to be_present }
      end

      context 'when product_analytics feature is not licensed' do
        before do
          stub_licensed_features(product_analytics: false)
        end

        it { is_expected.not_to be_present }
      end
    end

    describe 'Roles and permissions menu', feature_category: :user_management do
      let(:item_id) { :roles_and_permissions }

      context 'when custom_roles feature is licensed' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to be_present }

        context 'when in SaaS mode' do
          before do
            stub_saas_features(gitlab_com_subscriptions: true)
          end

          it { is_expected.not_to be_present }
        end
      end

      context 'when custom_roles feature is not licensed' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.not_to be_present }
      end
    end
  end
end
