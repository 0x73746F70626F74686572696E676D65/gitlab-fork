# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::PackagesRegistriesMenu, feature_category: :container_registry do
  let_it_be(:project) { create(:project) }
  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  describe 'Menu items' do
    subject { described_class.new(context).renderable_items.find { |i| i.item_id == item_id } }

    describe 'Google Artifact Registry' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      let(:item_id) { :google_artifact_registry }

      shared_examples 'the menu item is not added to list of menu items' do
        it 'does not add the menu item' do
          is_expected.to be_nil
        end
      end

      it { is_expected.not_to be_nil }

      context 'when feature flag is turned off' do
        before do
          stub_feature_flags(gcp_artifact_registry: false)
        end

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      context 'when feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      context 'when user is guest' do
        let_it_be(:user) { create(:user) }

        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'the menu item is not added to list of menu items'
      end

      context 'when user is anonymous' do
        let(:user) { nil }

        it_behaves_like 'the menu item is not added to list of menu items'
      end
    end
  end
end
