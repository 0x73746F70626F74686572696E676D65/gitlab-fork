# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::BaseAvailableServiceData, feature_category: :cloud_connector do
  let_it_be(:cut_off_date) { 1.day.ago }
  let_it_be(:purchased_add_ons) { %w[duo_pro] }

  describe '#free_access?' do
    subject(:free_access) { described_class.new(:duo_chat, cut_off_date, nil).free_access? }

    context 'when cut_off_date is in the past' do
      let_it_be(:cut_off_date) { 1.day.ago }

      it { is_expected.to be false }
    end

    context 'when cut_off_date is in the future' do
      let_it_be(:cut_off_date) { 1.day.from_now }

      it { is_expected.to be true }
    end
  end

  describe '#allowed_for?', :redis do
    let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:user) { create(:user) }

    let_it_be_with_reload(:active_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
    end

    let_it_be(:expired_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_add_on)
    end

    subject(:allowed_for?) { described_class.new(:duo_chat, cut_off_date, purchased_add_ons).allowed_for?(user) }

    shared_examples_for 'when the user has an active assigned seat' do
      context 'when the user has an active assigned seat' do
        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: active_gitlab_purchase
          )
        end

        it { is_expected.to be true }

        it 'caches the available services' do
          expect(GitlabSubscriptions::AddOnPurchase).to receive(:assigned_to_user).with(user).and_call_original

          2.times do
            allowed_for?
          end
        end
      end
    end

    context 'when on Gitlab.com instance', :saas do
      before do
        active_gitlab_purchase.namespace.add_owner(user)
      end

      include_examples 'when the user has an active assigned seat'
    end

    context 'when on Self managed instance' do
      let_it_be_with_reload(:active_gitlab_purchase) do
        create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: gitlab_add_on)
      end

      include_examples 'when the user has an active assigned seat'

      context 'when provided add-on name is code_suggestions' do
        let_it_be(:purchased_add_ons) { %w[code_suggestions] }

        include_examples 'when the user has an active assigned seat'
      end
    end

    context 'when the user has an expired assigned duo pro seat' do
      before do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_purchase
        )
      end

      it { is_expected.to be false }
    end

    context 'when the user has no add on seat assignments' do
      it { is_expected.to be false }
    end
  end

  describe '#purchased?' do
    let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }

    let_it_be_with_reload(:active_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
    end

    let_it_be(:expired_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_add_on)
    end

    subject(:purchased?) { described_class.new(:duo_chat, cut_off_date, purchased_add_ons).purchased?(namespace) }

    context 'when the add_on is purchased and active for a namespace' do
      let(:namespace) { active_gitlab_purchase.namespace }
      let_it_be_with_reload(:active_gitlab_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
      end

      it { is_expected.to be true }

      it 'calls by_namespace' do
        expect(GitlabSubscriptions::AddOnPurchase)
          .to receive(:by_namespace)
                .with(namespace.self_and_ancestor_ids)
                .and_call_original

        purchased?
      end
    end

    context 'when tha add_on is purchased and active for a parent namespace' do
      let(:namespace) { create(:group, parent: active_gitlab_purchase.namespace) }

      it { is_expected.to be true }

      context 'when provided add-on name is code_suggestions' do
        let_it_be(:purchased_add_ons) { %w[code_suggestions] }

        it { is_expected.to be true }
      end
    end

    context 'when the add_on is purchased but expired' do
      let(:namespace) { expired_gitlab_purchase.namespace }

      it { is_expected.to be false }
    end

    context 'when the add_on purchase has no namespace' do
      let(:namespace) { nil }

      it { is_expected.to be true }

      it 'doesn\'t call by_namespace' do
        expect(GitlabSubscriptions::AddOnPurchase).not_to receive(:by_namespace)

        purchased?
      end
    end
  end

  describe '#name' do
    subject(:name) { described_class.new(:duo_chat, cut_off_date, purchased_add_ons).name }

    it { is_expected.to eq(:duo_chat) }
  end

  describe '#access_token' do
    subject(:access_token) { described_class.new(:duo_chat, cut_off_date, purchased_add_ons).access_token(nil) }

    it 'raises not implemented exception' do
      expect { access_token }.to raise_error('Not implemented')
    end
  end
end
