# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveSession, feature_category: :system_access do
  describe '.set_marketing_user_cookies', :freeze_time do
    let_it_be(:user) { create(:user, :with_namespace) }
    let(:auth) { double(cookies: {}) } # rubocop:todo RSpec/VerifiedDoubles -- similar to the foss class for now

    subject(:set_marketing_user_cookies) { described_class.set_marketing_user_cookies(auth, user) }

    context 'when the gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'sets marketing user cookies' do
        set_marketing_user_cookies

        expect(auth.cookies[:gitlab_user][:value]).to be_truthy
        expect(auth.cookies[:gitlab_user][:expires]).to be_within(1.minute).of(2.weeks.from_now)
        expect(auth.cookies[:gitlab_tier][:value]).not_to be_nil
        expect(auth.cookies[:gitlab_tier][:expires]).to be_within(1.minute).of(2.weeks.from_now)
      end

      context 'with no plans' do
        it 'sets marketing tier cookie to false' do
          set_marketing_user_cookies

          expect(auth.cookies[:gitlab_tier][:value]).to eq false
        end
      end

      context 'with one plan' do
        it 'sets marketing tier cookie a singular plan name', :saas do
          create(:group_with_plan, plan: :free_plan, owners: user)

          set_marketing_user_cookies

          expect(auth.cookies[:gitlab_tier][:value]).to eq ['free']
        end
      end

      context 'with multiple plans' do
        it 'sets marketing tier cookie with multiple plan names', :saas do
          create(:group_with_plan, plan: :free_plan, owners: user)
          create(:group_with_plan, plan: :ultimate_plan, owners: user)

          set_marketing_user_cookies

          expect(auth.cookies[:gitlab_tier][:value]).to eq %w[free ultimate]
        end
      end

      context 'when the add_gitlab_tier_cookie feature flag is disabled' do
        before do
          stub_feature_flags(add_gitlab_tier_cookie: false)
        end

        it 'does not set the tier cookie' do
          described_class.set_marketing_user_cookies(auth, user)

          expect(auth.cookies[:gitlab_user]).to be_present
          expect(auth.cookies[:gitlab_tier]).to be_nil
        end
      end
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not set the marketing cookies' do
        described_class.set_marketing_user_cookies(auth, user)

        expect(auth.cookies[:gitlab_user]).to be_nil
        expect(auth.cookies[:gitlab_tier]).to be_nil
      end
    end
  end
end
