# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SidebarsHelper, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax
  include Devise::Test::ControllerHelpers

  describe '#super_sidebar_context' do
    let(:user_namespace) { build_stubbed(:namespace) }
    let(:user) { build_stubbed(:user, namespace: user_namespace) }
    let(:panel) { {} }
    let(:panel_type) { 'project' }
    let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(user) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(user_namespace).to receive(:actual_plan_name).and_return(::Plan::ULTIMATE)
      allow(helper).to receive(:current_user_menu?).and_return(true)
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:show_buy_pipeline_with_subtext?).and_return(true)
      allow(helper).to receive(:current_user_mode).and_return(current_user_mode)
      allow(panel).to receive(:super_sidebar_menu_items).and_return(nil)
      allow(panel).to receive(:super_sidebar_context_header).and_return(nil)
      allow(user).to receive(:assigned_open_issues_count).and_return(1)
      allow(user).to receive(:assigned_open_merge_requests_count).and_return(4)
      allow(user).to receive(:review_requested_open_merge_requests_count).and_return(0)
      allow(user).to receive(:todos_pending_count).and_return(3)
      allow(user).to receive(:total_merge_requests_count).and_return(4)
    end

    # Tests for logged-out sidebar context,
    # because EE/CE should have the same attributes for logged-out users
    it_behaves_like 'logged-out super-sidebar context'

    shared_examples 'compute minutes attributes' do
      it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context).to have_key(:pipeline_minutes)
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          show_buy_pipeline_minutes: true,
          show_notification_dot: false,
          show_with_subtext: true,
          tracking_attrs: {
            'track-action': 'click_buy_ci_minutes',
            'track-label': ::Plan::DEFAULT,
            'track-property': 'user_dropdown'
          },
          notification_dot_attrs: {
            'data-track-action': 'render',
            'data-track-label': 'show_buy_ci_minutes_notification',
            'data-track-property': ::Plan::ULTIMATE
          },
          callout_attrs: {
            feature_id: ::Ci::RunnersHelper::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT,
            dismiss_endpoint: '/-/users/callouts'
          }
        })
      end
    end

    shared_examples 'trial status widget data' do
      describe 'trial status when subscriptions_trials feature is available', :saas do
        let_it_be(:root_group) { namespace }
        let_it_be(:gitlab_subscription) { build(:gitlab_subscription, :active_trial, namespace: root_group) }

        before do
          stub_saas_features(subscriptions_trials: true)
          allow(root_group).to receive(:actual_plan_name).and_return('_actual_plan_name_')
        end

        describe 'does not return trial status widget data' do
          it { is_expected.not_to include(:trial_status_widget_data_attrs) }
          it { is_expected.not_to include(:trial_status_popover_data_attrs) }
        end

        context 'when a namespace is qualified for trial status widget' do
          before do
            # need to stub a default for the other can? uses first
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_namespace, root_group).and_return(true)
          end

          it 'returns trial status widget data' do
            expect(super_sidebar_context).to include(:trial_status_widget_data_attrs, :trial_status_popover_data_attrs)
          end
        end
      end
    end

    shared_examples 'duo pro trial status widget data' do
      describe 'duo pro trial status', :saas do
        let_it_be(:root_group) { namespace }
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: root_group) # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for interaction with other records
        end

        before do
          stub_saas_features(subscriptions_trials: true)
        end

        describe 'does not return trial status widget data' do
          it { is_expected.not_to include(:duo_pro_trial_status_widget_data_attrs) }
          it { is_expected.not_to include(:duo_pro_trial_status_popover_data_attrs) }
        end

        context 'when a namespace is qualified for duo pro trial status widget' do
          before do
            # need to stub a default for the other can? uses first
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_namespace, root_group).and_return(true)
          end

          context 'when only qualified for duo pro' do
            let_it_be(:gitlab_subscription) { build(:gitlab_subscription, :ultimate, namespace: root_group) }

            it { is_expected.to include(:duo_pro_trial_status_widget_data_attrs) }
            it { is_expected.to include(:duo_pro_trial_status_popover_data_attrs) }
          end

          context 'when a namespace is also qualified for a trial status widget' do
            let_it_be(:gitlab_subscription) { build(:gitlab_subscription, :active_trial, namespace: root_group) }

            it { is_expected.to include(:trial_status_widget_data_attrs) }
            it { is_expected.to include(:trial_status_popover_data_attrs) }
            it { is_expected.not_to include(:duo_pro_trial_status_widget_data_attrs) }
            it { is_expected.not_to include(:duo_pro_trial_status_popover_data_attrs) }
          end
        end
      end
    end

    context 'with global concerns' do
      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: nil, project: nil, panel: panel, panel_type: nil)
      end

      it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
        trial = {
          has_start_trial: false,
          url: new_trial_path(glm_source: 'gitlab.com', glm_content: 'top-right-dropdown')
        }

        expect(super_sidebar_context).to include(trial: trial)
      end
    end

    context 'when in project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let_it_be(:project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for interaction with other records
      let_it_be(:namespace) { project.namespace }
      let(:group) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'compute minutes attributes'
      include_examples 'trial status widget data'
      include_examples 'duo pro trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/-/profile/usage_quotas"
        })
      end
    end

    context 'when in group scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for interaction with other records
      let_it_be(:namespace) { group }
      let(:project) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'compute minutes attributes'
      include_examples 'trial status widget data'
      include_examples 'duo pro trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/groups/#{group.path}/-/usage_quotas"
        })
      end
    end

    context 'when neither in a group nor in a project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(false)
      end

      let(:project) { nil }
      let(:group) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      it 'does not have compute minutes attributes' do
        expect(super_sidebar_context).not_to have_key('pipeline_minutes')
      end

      it 'returns paths for user', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/461171' do
        expect(super_sidebar_context).to match(hash_including({
          sign_out_link: '/users/sign_out',
          issues_dashboard_path: "/dashboard/issues?assignee_username=#{user.username}",
          merge_request_dashboard_path: nil,
          todos_dashboard_path: '/dashboard/todos',
          projects_path: '/dashboard/projects',
          groups_path: '/dashboard/groups'
        }))
      end

      context 'with merge_request_dashboard feature flag enabled' do
        before do
          stub_feature_flags(merge_request_dashboard: user)
        end

        it 'has merge_request_dashboard_path' do
          expect(super_sidebar_context[:merge_request_dashboard_path]).to eq('/dashboard/merge_requests')
        end
      end
    end
  end
end
