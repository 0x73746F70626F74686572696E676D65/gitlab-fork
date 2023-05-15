# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SettingsMenu do
  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project) }

  subject { described_class.new(context) }

  before do
    stub_feature_flags(show_pages_in_deployments_menu: false)
  end

  describe '#render?' do
    it 'returns false when menu does not have any menu items' do
      allow(subject).to receive(:has_renderable_items?).and_return(false)

      expect(subject.render?).to be false
    end
  end

  describe '#separated?' do
    it 'returns true' do
      expect(subject.separated?).to be true
    end
  end

  describe 'Menu items' do
    subject { described_class.new(context).renderable_items.find { |e| e.item_id == item_id } }

    shared_examples 'access rights checks' do
      specify { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        specify { is_expected.to be_nil }
      end
    end

    describe 'General' do
      let(:item_id) { :general }

      it_behaves_like 'access rights checks'
    end

    describe 'Integrations' do
      let(:item_id) { :integrations }

      it_behaves_like 'access rights checks'
    end

    describe 'Webhooks' do
      let(:item_id) { :webhooks }

      it_behaves_like 'access rights checks'
    end

    describe 'Access Tokens' do
      let(:item_id) { :access_tokens }

      it_behaves_like 'access rights checks'
    end

    describe 'Repository' do
      let(:item_id) { :repository }

      it_behaves_like 'access rights checks'
    end

    describe 'CI/CD' do
      let(:item_id) { :ci_cd }

      describe 'when project is archived' do
        before do
          allow(project).to receive(:archived?).and_return(true)
        end

        specify { is_expected.to be_nil }
      end

      describe 'when project is not archived' do
        specify { is_expected.not_to be_nil }

        describe 'when the user does not have access' do
          let(:user) { nil }

          specify { is_expected.to be_nil }
        end
      end
    end

    describe 'Monitor' do
      let(:item_id) { :monitor }

      describe 'when project is archived' do
        before do
          allow(project).to receive(:archived?).and_return(true)
        end

        specify { is_expected.to be_nil }
      end

      describe 'when project is not archived' do
        specify { is_expected.not_to be_nil }

        specify { expect(subject.title).to eq 'Monitor' }

        describe 'when the user does not have access' do
          let(:user) { nil }

          specify { is_expected.to be_nil }
        end
      end
    end

    describe 'Pages' do
      let(:item_id) { :pages }

      before do
        allow(project).to receive(:pages_available?).and_return(pages_enabled)
      end

      describe 'when pages are enabled' do
        let(:pages_enabled) { true }

        specify { is_expected.not_to be_nil }

        describe 'when the user does not have access' do
          let(:user) { nil }

          specify { is_expected.to be_nil }
        end
      end

      describe 'when pages are not enabled' do
        let(:pages_enabled) { false }

        specify { is_expected.to be_nil }
      end
    end

    describe 'Merge requests' do
      let(:item_id) { :merge_requests }

      it_behaves_like 'access rights checks'
    end

    describe 'Packages and registries' do
      let(:item_id) { :packages_and_registries }
      let(:packages_enabled) { false }

      before do
        stub_container_registry_config(enabled: container_enabled)
        stub_config(packages: { enabled: packages_enabled })
      end

      describe 'when container registry setting is disabled' do
        let(:container_enabled) { false }

        specify { is_expected.to be_nil }
      end

      describe 'when container registry setting is enabled' do
        let(:container_enabled) { true }

        specify { is_expected.not_to be_nil }

        describe 'when the user does not have access' do
          let(:user) { nil }

          specify { is_expected.to be_nil }
        end
      end

      describe 'when package registry setting is enabled' do
        let(:container_enabled) { false }
        let(:packages_enabled) { true }

        specify { is_expected.not_to be_nil }

        describe 'when the user does not have access' do
          let(:user) { nil }

          specify { is_expected.to be_nil }
        end
      end
    end

    describe 'Usage Quotas' do
      let(:item_id) { :usage_quotas }

      specify { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        specify { is_expected.to be_nil }
      end
    end
  end
end
