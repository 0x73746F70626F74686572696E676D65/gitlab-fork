# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/billings/index', :saas, :aggregate_failures, feature_category: :subscription_management do
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :free_plan) }
  let_it_be(:plans_data) { billing_plans_data.map { |plan| Hashie::Mash.new(plan) } }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
    assign(:plans_data, plans_data)
  end

  context 'when the group is the top level' do
    context 'with free plan' do
      it 'renders the billing page' do
        render

        expect(rendered).not_to have_selector('#js-billing-plans')
        expect(rendered).to have_text('is currently using the')
        expect(rendered).to have_text('Not the group')
        expect(rendered).to have_link('Switch to a different group', href: dashboard_groups_path)

        page = Capybara.string(rendered)

        # free
        scoped_node = page.find("[data-testid='plan-card-free']")

        expect(scoped_node).to have_content('Your current plan')
        expect(scoped_node).to have_content('Free')
        expect(scoped_node).to have_content('Use GitLab for personal projects')

        # premium
        scoped_node = page.find("[data-testid='plan-card-premium']")

        expect(scoped_node).to have_content('Recommended')
        expect(scoped_node).to have_content('Premium')
        expect(scoped_node).to have_content('For scaling organizations and multi-team usage')
        expect(scoped_node).to have_link('Upgrade to Premium')

        # ultimate
        scoped_node = page.find("[data-testid='plan-card-ultimate']")

        expect(scoped_node).to have_content('Ultimate')
        expect(scoped_node).to have_content('For enterprises looking to deliver software faster')
        expect(scoped_node).to have_link('Upgrade to Ultimate')

        expect(rendered).to have_link('Start a free Ultimate trial', href: new_trial_path(namespace_id: group.id))
      end

      it 'has tracking items set as expected' do
        render

        expect_to_have_tracking(action: 'render')
        expect_to_have_tracking(action: 'click_button', label: 'view_all_groups')
        expect_to_have_tracking(action: 'click_button', label: 'start_trial')
      end

      def expect_to_have_tracking(action:, label: nil)
        css = "[data-track-action='#{action}']"
        css += "[data-track-label='#{label}']" if label

        expect(rendered).to have_css(css)
      end

      context 'with an expired trial' do
        let_it_be(:group) { create(:group_with_plan, plan: :free_plan, trial_ends_on: Date.yesterday) }

        it 'omits the trial CTA' do
          render

          expect(rendered).not_to have_link('Start a free Ultimate trial')
        end
      end
    end

    context 'with an active trial' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_trial_plan, trial_ends_on: 10.days.from_now) }

      it 'renders the billing page without the trial CTA' do
        render

        expect(rendered).to have_selector('#js-billing-plans')
        expect(rendered).to have_text('Your GitLab.com Ultimate trial will expire after')

        expect(rendered).not_to have_link('Start a free Ultimate trial')
      end
    end

    context 'with a paid plan' do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'renders the billing plans' do
        render

        expect(rendered).to render_template('_top_level_billing_plan_header')
        expect(rendered).to render_template('shared/billings/_billing_plans')
        expect(rendered).to have_selector('#js-billing-plans')
      end

      context 'with Duo Pro trial link' do
        context 'when duo_pro_trials is enabled' do
          before do
            stub_feature_flags(duo_pro_trials: true)
          end

          it 'renders the link' do
            render

            expect(rendered).to have_link(
              'Start a free GitLab Duo Pro trial',
              href: new_trials_duo_pro_path(namespace_id: group.id)
            )
          end
        end

        context 'when duo_pro_trials is disabled' do
          before do
            stub_feature_flags(duo_pro_trials: false)
          end

          it 'does not render the link' do
            render

            expect(rendered).not_to have_link(
              'Start a free GitLab Duo Pro trial',
              href: new_trials_duo_pro_path(namespace_id: group.id)
            )
          end
        end
      end

      context 'with code suggestions' do
        it 'renders the code suggestions component' do
          tracking = {
            action: 'click_button',
            label: 'code_suggestions_hand_raise_lead_form'
          }.to_json
          hand_raise_selector = ".js-hand-raise-lead-trigger[data-cta-tracking='#{tracking}']"

          render

          expect(rendered).to have_content(s_('CodeSuggestions|Introducing the GitLab Duo Pro add-on'))

          expect(rendered).to have_content(
            'Boost productivity across the software development life cycle by using ' \
            'Code Suggestions and GitLab Duo Chat'
          )

          expect(rendered).to have_content(_('You can now try GitLab Duo Pro for free for 60 days'))
          expect(rendered).to have_link('GitLab Duo Pro', href: 'https://about.gitlab.com/gitlab-duo/')
          expect(rendered).to have_selector(hand_raise_selector)
        end
      end
    end

    context 'when purchasing a plan' do
      before do
        allow(view).to receive(:params).and_return(purchased_quantity: quantity)
        allow(view).to receive(:plan_title).and_return('Bronze')
      end

      let(:quantity) { '1' }

      it 'tracks purchase banner', :snowplow do
        render

        expect_snowplow_event(
          category: 'groups:billings',
          action: 'render',
          label: 'purchase_confirmation_alert_displayed',
          namespace: group,
          user: user
        )
      end

      context 'with a single user' do
        it 'displays the correct notification for 1 user' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 1 user and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end

      context 'with multiple users' do
        let(:quantity) { '2' }

        it 'displays the correct notification for 2 users' do
          render

          expect(rendered).to have_text('You\'ve successfully purchased the Bronze plan subscription for 2 users and ' \
                                    'you\'ll receive a receipt by email. Your purchase may take a minute to sync, ' \
                                    'refresh the page if your subscription details haven\'t displayed yet.')
        end
      end
    end
  end
end
