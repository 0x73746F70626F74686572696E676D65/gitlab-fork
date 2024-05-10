# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SettingsMenu, feature_category: :navigation do
  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }

  let(:show_promotions) { true }
  let(:show_discover_project_security) { true }
  let(:context) do
    Sidebars::Projects::Context.new(current_user: user, container: project, show_promotions: show_promotions,
      show_discover_project_security: show_discover_project_security)
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

    describe 'Analytics' do
      let(:item_id) { :analytics }

      context 'for group projects' do
        let_it_be(:user) { create(:user) }
        let_it_be(:group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, group: group) }

        before_all do
          project.add_maintainer(user)
        end

        it_behaves_like 'access rights checks'

        it 'is nil when combined_analytics_dashboards feature flag is disabled' do
          stub_feature_flags(combined_analytics_dashboards: false)
          expect(subject).to be_nil
        end
      end

      context 'for personal projects' do
        it 'is nil for personal namespace projects' do
          is_expected.to be_nil
        end
      end
    end

    describe 'General' do
      let(:item_id) { :general }

      describe 'when the user is not an admin' do
        let_it_be(:user) { create(:user) }

        before_all do
          project.add_guest(user)
        end

        before do
          allow(Ability).to receive(:allowed?).and_call_original
        end

        it 'does not include the general menu item' do
          expect(subject).to be_nil
        end

        context 'when the user has the `view_edit_page` ability' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :view_edit_page, project).and_return(true)
          end

          it 'includes the general menu item' do
            expect(subject.title).to eql('General')
          end
        end
      end
    end

    describe 'Access Tokens' do
      let(:item_id) { :access_tokens }

      describe 'when the user is not an admin but has manage_resource_access_tokens custom permission' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :manage_resource_access_tokens, project).and_return(true)
        end

        it 'includes access token menu item' do
          expect(subject.title).to eql('Access Tokens')
        end
      end
    end

    describe 'CI/CD' do
      let(:item_id) { :ci_cd }

      describe 'when the user is not an admin but has `admin_cicd_variables` custom ability' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :admin_cicd_variables, project).and_return(true)
        end

        it 'includes CI/CD menu item' do
          expect(subject.title).to eql('CI/CD')
        end
      end
    end

    describe 'Repository' do
      let(:item_id) { :repository }

      describe 'when the user is not an admin of the project but has `admin_push_rules` custom ability' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :admin_push_rules, project).and_return(true)
        end

        it 'includes repository menu item' do
          expect(subject.title).to eql('Repository')
        end
      end

      describe 'when the user is not an admin but has the `manage_deploy_tokens` custom permission' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_project, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :manage_deploy_tokens, project).and_return(true)
        end

        it 'includes Repository menu item' do
          expect(subject.title).to eql('Repository')
        end
      end
    end
  end
end
