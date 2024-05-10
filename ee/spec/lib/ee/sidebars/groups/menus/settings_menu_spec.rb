# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::SettingsMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be(:auditor) { create(:user, :auditor) }

  let_it_be_with_refind(:group) do
    build(:group, :private).tap do |g|
      g.add_owner(owner)
      g.add_member(auditor, :reporter)
    end
  end

  let_it_be_with_refind(:subgroup) { create(:group, :private, parent: group) }
  let(:show_promotions) { false }
  let(:container) { group }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: container, show_promotions: show_promotions) }
  let(:menu) { described_class.new(context) }

  describe 'Menu Items' do
    context 'for owner user' do
      let(:user) { owner }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      describe 'Roles and permissions menu', feature_category: :user_management do
        let(:item_id) { :roles_and_permissions }

        context 'when custom_roles feature is licensed' do
          before do
            stub_licensed_features(custom_roles: true)
            stub_saas_features(gitlab_com_subscriptions: true)
          end

          it { is_expected.to be_present }

          context 'when it is not a root group' do
            let_it_be_with_refind(:subgroup) do
              create(:group, :private, parent: group).tap do |g|
                g.add_owner(owner)
              end
            end

            let(:container) { subgroup }

            it { is_expected.not_to be_present }
          end

          context 'when on self-managed' do
            before do
              stub_saas_features(gitlab_com_subscriptions: false)
            end

            it { is_expected.not_to be_present }
          end
        end

        context 'when custom_roles feature is not licensed' do
          before do
            stub_licensed_features(custom_roles: false)
            stub_saas_features(gitlab_com_subscriptions: true)
          end

          it { is_expected.not_to be_present }
        end
      end

      describe 'LDAP sync menu' do
        let(:item_id) { :ldap_sync }

        before do
          allow(Gitlab::Auth::Ldap::Config).to receive(:group_sync_enabled?).and_return(sync_enabled)
        end

        context 'when group LDAP sync is not enabled' do
          let(:sync_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when group LDAP sync is enabled' do
          let(:sync_enabled) { true }

          context 'when user can admin LDAP syncs' do
            it { is_expected.to be_present }
          end

          context 'when user cannot admin LDAP syncs' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'SAML SSO menu' do
        let(:item_id) { :saml_sso }
        let(:saml_enabled) { true }

        before do
          stub_licensed_features(group_saml: saml_enabled)
          allow(::Gitlab::Auth::GroupSaml::Config).to receive(:enabled?).and_return(saml_enabled)
        end

        context 'when SAML is disabled' do
          let(:saml_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when SAML is enabled' do
          it { is_expected.to be_present }

          context 'when user cannot admin group SAML' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'SAML group links menu' do
        let(:item_id) { :saml_group_links }
        let(:saml_group_links_enabled) { true }

        before do
          allow(::Gitlab::Auth::GroupSaml::Config).to receive(:enabled?).and_return(saml_group_links_enabled)
          allow(group).to receive(:saml_group_sync_available?).and_return(saml_group_links_enabled)
        end

        context 'when SAML group links feature is disabled' do
          let(:saml_group_links_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when SAML group links feature is enabled' do
          it { is_expected.to be_present }

          context 'when user cannot admin SAML group links' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end
      end

      describe 'domain verification', :saas do
        let(:item_id) { :domain_verification }

        context 'when domain verification is licensed' do
          before do
            stub_licensed_features(domain_verification: true)
          end

          it { is_expected.to be_present }

          context 'when user cannot admin group' do
            let(:user) { nil }

            it { is_expected.not_to be_present }
          end
        end

        context 'when domain verification is not licensed' do
          before do
            stub_licensed_features(domain_verification: false)
          end

          it { is_expected.not_to be_present }
        end
      end

      describe 'Webhooks menu' do
        let(:item_id) { :webhooks }
        let(:group_webhooks_enabled) { true }

        before do
          stub_licensed_features(group_webhooks: group_webhooks_enabled)
        end

        context 'when licensed feature :group_webhooks is not enabled' do
          let(:group_webhooks_enabled) { false }

          it { is_expected.not_to be_present }
        end

        context 'when show_promotions is enabled' do
          let(:show_promotions) { true }

          it { is_expected.to be_present }
        end

        context 'when licensed feature :group_webhooks is enabled' do
          it { is_expected.to be_present }
        end
      end

      describe 'Usage quotas menu' do
        let(:item_id) { :usage_quotas }

        it { is_expected.to be_present }

        context 'when subgroup' do
          let(:container) { subgroup }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Billing menu' do
        let(:item_id) { :billing }
        let(:check_billing) { true }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(check_billing)
        end

        it { is_expected.to be_present }

        context 'when group billing does not apply' do
          let(:check_billing) { false }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Reporting menu' do
        let(:item_id) { :reporting }
        let(:feature_enabled) { true }

        before do
          allow(group).to receive(:unique_project_download_limit_enabled?) { feature_enabled }
        end

        it { is_expected.to be_present }

        context 'when feature is not enabled' do
          let(:feature_enabled) { false }

          it { is_expected.not_to be_present }
        end
      end

      describe 'Analytics menu' do
        let(:item_id) { :analytics }
        let(:feature_enabled) { true }

        before do
          allow(menu).to receive(:group_analytics_settings_available?).with(user, group).and_return(feature_enabled)
          menu.configure_menu_items
        end

        it { is_expected.to be_present }

        context 'when feature is not enabled' do
          let(:feature_enabled) { false }

          it { is_expected.not_to be_present }
        end
      end
    end

    context 'for auditor user' do
      let(:user) { auditor }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      describe 'Roles and permissions menu', feature_category: :user_management do
        let(:item_id) { :roles_and_permissions }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.not_to be_present }
      end

      describe 'Billing menu item' do
        let(:item_id) { :billing }
        let(:check_billing) { true }

        before do
          allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(check_billing)
        end

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'for user with `read_resource_access_tokens` custom permission', feature_category: :permissions do
      let_it_be(:user) { create(:user) }
      let_it_be(:role) { create(:member_role, :guest, namespace: group, manage_group_access_tokens: true) }
      let_it_be(:member) { create(:group_member, :guest, member_role: role, user: user, group: group) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        stub_licensed_features(custom_roles: true)
      end

      describe 'Access Tokens menu item' do
        let(:item_id) { :access_tokens }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'when the user is not an owner but has `admin_cicd_variables` custom ability', feature_category: :permissions do
      let_it_be(:user) { create(:user) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :admin_cicd_variables, group).and_return(true)
      end

      describe 'CI/CD menu item' do
        let(:item_id) { :ci_cd }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'when the user is not an admin of the group but has `admin_push_rules` custom ability', feature_category: :permissions do
      let_it_be(:user) { create(:user) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :admin_push_rules, group).and_return(true)
      end

      describe 'Repository menu item' do
        let(:item_id) { :repository }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'when the user is not an owner but has `remove_group` custom ability', feature_category: :permissions do
      let_it_be(:user) { create(:user) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :remove_group, group).and_return(true)
      end

      describe 'General menu item' do
        let(:item_id) { :general }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'when the user is not an owner but has `admin_compliance_framework` custom ability', feature_category: :compliance_management do
      let_it_be(:user) { create(:user) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :admin_compliance_framework, group).and_return(true)
      end

      describe 'General menu item' do
        let(:item_id) { :general }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end

    context 'when the user is not an owner but has `manage_deploy_tokens` custom permission', feature_category: :continuous_delivery do
      let_it_be(:user) { create(:user) }

      subject { menu.renderable_items.find { |e| e.item_id == item_id } }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :admin_group, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :manage_deploy_tokens, group).and_return(true)
      end

      describe 'General menu item' do
        let(:item_id) { :repository }

        it { is_expected.to be_present }

        it 'does not show any other menu items' do
          expect(menu.renderable_items.length).to equal(1)
        end
      end
    end
  end
end
