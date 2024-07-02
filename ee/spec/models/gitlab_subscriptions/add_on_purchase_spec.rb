# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchase, feature_category: :plan_provisioning do
  subject { build(:gitlab_subscription_add_on_purchase) }

  it { is_expected.to include_module(EachBatch) }

  describe 'constants' do
    it { expect(described_class::CLEANUP_DELAY_PERIOD).to be_a(ActiveSupport::Duration) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:add_on).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on_purchases) }
    it { is_expected.to belong_to(:namespace).optional(true) }
    it { is_expected.to belong_to(:organization) }

    it do
      is_expected.to have_many(:assigned_users)
        .class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:add_on) }
    it { is_expected.to validate_presence_of(:expires_on) }

    context 'when validating namespace' do
      context 'when on .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        using RSpec::Parameterized::TableSyntax

        let_it_be(:group_namespace) { create(:group) }
        let_it_be(:sub_group_namespace) { create(:group, parent: group_namespace) }
        let_it_be(:project_namespace) { create(:project_namespace) }
        let_it_be(:user_namespace) { create(:user_namespace) }

        where(:namespace, :result) do
          ref(:group_namespace)     | true
          ref(:sub_group_namespace) | false
          ref(:project_namespace)   | false
          ref(:user_namespace)      | false
          nil                       | false
        end

        with_them do
          it 'validates the namespace correctly' do
            record = build(:gitlab_subscription_add_on_purchase, namespace: namespace)

            expect(record.valid?).to eq(result)
            expect(record.errors.of_kind?(:namespace, :invalid)).to eq(!result)
          end
        end
      end

      context 'when not on .com' do
        it { is_expected.not_to validate_presence_of(:namespace) }
      end
    end

    it { is_expected.to validate_uniqueness_of(:subscription_add_on_id).scoped_to(:namespace_id) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(1) }

    it { is_expected.to validate_presence_of(:purchase_xid) }
    it { is_expected.to validate_length_of(:purchase_xid).is_at_most(255) }
  end

  describe 'scopes' do
    shared_context 'with add-on purchases' do
      let_it_be(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:expired_gitlab_duo_pro_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:expired_product_analytics_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:user) { create(:user) }

      before do
        expired_gitlab_duo_pro_purchase_as_owner.namespace.add_owner(user)
        active_gitlab_duo_pro_purchase_as_guest.namespace.add_guest(user)
        active_gitlab_duo_pro_purchase_as_reporter.namespace.add_reporter(user)
        active_gitlab_duo_pro_purchase_as_developer.namespace.add_developer(user)
        active_gitlab_duo_pro_purchase_as_maintainer.namespace.add_maintainer(user)

        expired_product_analytics_purchase_as_owner.namespace.add_owner(user)
        active_product_analytics_purchase_as_guest.namespace.add_guest(user)
        active_product_analytics_purchase_as_reporter.namespace.add_reporter(user)
        active_product_analytics_purchase_as_developer.namespace.add_developer(user)
        active_product_analytics_purchase_as_maintainer.namespace.add_maintainer(user)
      end
    end

    describe '.active' do
      include_context 'with add-on purchases'

      subject(:active_purchases) { described_class.active }

      it 'returns all the purchases that are not expired' do
        expect(active_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest, active_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer, active_gitlab_duo_pro_purchase_as_maintainer,
            active_gitlab_duo_pro_purchase_unrelated, active_product_analytics_purchase_as_guest,
            active_product_analytics_purchase_as_reporter, active_product_analytics_purchase_as_developer,
            active_product_analytics_purchase_as_maintainer, active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.ready_for_cleanup' do
      let(:add_on) { create(:gitlab_subscription_add_on) }
      let(:active_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: Date.current
        )
      end

      let(:ready_for_clean_up_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: (described_class::CLEANUP_DELAY_PERIOD + 1.day).ago.to_date
        )
      end

      before do
        active_add_on_purchase
        ready_for_clean_up_add_on_purchase
      end

      it 'returns all ready for cleanup add on purchases' do
        expect(described_class.ready_for_cleanup).to match_array(ready_for_clean_up_add_on_purchase)
      end
    end

    describe '.trial' do
      include_context 'with add-on purchases'

      let_it_be(:gitlab_duo_pro_purchase_trial) do
        create(:gitlab_subscription_add_on_purchase, :trial, add_on: gitlab_duo_pro_add_on)
      end

      subject(:trials) { described_class.trial }

      it 'returns all the purchases that are not expired' do
        expect(trials).to match_array([gitlab_duo_pro_purchase_trial])
      end
    end

    describe '.by_add_on_name' do
      subject(:by_name_purchases) { described_class.by_add_on_name(name) }

      include_context 'with add-on purchases'

      context 'when name is: code_suggestions' do
        let(:name) { 'code_suggestions' }

        it 'returns all the purchases related to gitlab_duo_pro' do
          expect(by_name_purchases).to match_array(
            [
              expired_gitlab_duo_pro_purchase_as_owner, active_gitlab_duo_pro_purchase_as_guest,
              active_gitlab_duo_pro_purchase_as_reporter, active_gitlab_duo_pro_purchase_as_developer,
              active_gitlab_duo_pro_purchase_as_maintainer, active_gitlab_duo_pro_purchase_unrelated
            ]
          )
        end
      end

      context 'when name is set to anything else' do
        let(:name) { 'foo-bar' }

        it 'returns empty collection' do
          expect(by_name_purchases).to eq([])
        end
      end
    end

    describe '.by_namespace_id' do
      subject(:result) { described_class.by_namespace_id(namespace_id) }

      include_context 'with add-on purchases'

      context 'when record with given namespace_id exists' do
        let(:namespace_id) { active_gitlab_duo_pro_purchase_as_maintainer.namespace_id }

        it { is_expected.to contain_exactly(active_gitlab_duo_pro_purchase_as_maintainer) }
      end

      context 'when record with given namespace_id does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to match_array([]) }
      end

      context 'when nil is given' do
        let(:namespace_id) { nil }

        context 'and the record exist' do
          let(:add_on_purchase_with_namespace_id_nil) do
            create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, namespace_id: nil)
          end

          it { is_expected.to contain_exactly(add_on_purchase_with_namespace_id_nil) }
        end

        context 'and the record does not exist' do
          it { is_expected.to match_array([]) }
        end
      end
    end

    describe '.for_gitlab_duo_pro' do
      subject(:gitlab_duo_pro_purchases) { described_class.for_gitlab_duo_pro }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to gitlab duo' do
        expect(gitlab_duo_pro_purchases).to match_array(
          [
            expired_gitlab_duo_pro_purchase_as_owner, active_gitlab_duo_pro_purchase_as_guest,
            active_gitlab_duo_pro_purchase_as_reporter, active_gitlab_duo_pro_purchase_as_developer,
            active_gitlab_duo_pro_purchase_as_maintainer, active_gitlab_duo_pro_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_product_analytics' do
      subject(:product_analytics_purchases) { described_class.for_product_analytics }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to product_analytics' do
        expect(product_analytics_purchases).to match_array(
          [
            expired_product_analytics_purchase_as_owner, active_product_analytics_purchase_as_guest,
            active_product_analytics_purchase_as_reporter, active_product_analytics_purchase_as_developer,
            active_product_analytics_purchase_as_maintainer, active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_user', :saas do
      subject(:user_purchases) { described_class.for_user(user) }

      include_context 'with add-on purchases'

      it 'returns all the non-guest purchases related to the user top level namespaces' do
        expect(user_purchases).to match_array(
          [
            expired_gitlab_duo_pro_purchase_as_owner, active_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer, active_gitlab_duo_pro_purchase_as_maintainer,
            expired_product_analytics_purchase_as_owner, active_product_analytics_purchase_as_reporter,
            active_product_analytics_purchase_as_developer, active_product_analytics_purchase_as_maintainer
          ]
        )
      end
    end

    describe '.assigned_to_user', :saas do
      before do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_guest
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_developer
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_duo_pro_purchase_as_owner
        )
      end

      subject(:user_purchases) { described_class.assigned_to_user(user) }

      include_context 'with add-on purchases'

      it 'returns all active purchases related to the user add-on assignments' do
        expect(user_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_developer,
            active_gitlab_duo_pro_purchase_as_guest
          ]
        )
      end
    end

    describe '.requiring_assigned_users_refresh' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:add_on_purchase_refreshed_nil) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }
      let_it_be(:add_on_purchase_fresh) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
      end

      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns correct add_on_purchases' do
        result = [
          add_on_purchase_refreshed_nil,
          add_on_purchase_stale
        ]

        expect(described_class.requiring_assigned_users_refresh(3))
          .to match_array(result)
      end

      it 'accepts limit param' do
        expect(described_class.requiring_assigned_users_refresh(1).size).to eq 1
      end
    end
  end

  describe '.uniq_add_on_names' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

    before do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
    end

    subject(:add_on_names) { described_class.uniq_add_on_names }

    it { is_expected.to match_array('code_suggestions') }
  end

  describe '.next_candidate_requiring_assigned_users_refresh' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    subject(:next_candidate) { described_class.next_candidate_requiring_assigned_users_refresh }

    context 'when there are stale records' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns the stale record' do
        expect(next_candidate).to eq(add_on_purchase_stale)
      end

      context 'when there is stale records with nil refreshed_at' do
        it 'returns record with nil refreshed_at as next candidate' do
          result = create(:gitlab_subscription_add_on_purchase, add_on: add_on)

          expect(next_candidate).to eq(result)
        end
      end

      context 'when there is stale record with earlier refreshed_at' do
        it 'returns record with earlier refreshed_at as next candidate' do
          result = create(
            :gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago
          )

          expect(next_candidate).to eq(result)
        end
      end
    end

    it 'returns nil when there are no stale records' do
      expect(next_candidate).to eq(nil)
    end
  end

  describe '#already_assigned?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let(:user) { create(:user) }

    subject { add_on_purchase.already_assigned?(user) }

    context 'when the user has been already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it { is_expected.to eq(true) }
    end

    context 'when user is not already assigned' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#active?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.active? }

    it { is_expected.to eq(true) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(false) } }
    end
  end

  describe '#expired?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.expired? }

    it { is_expected.to eq(false) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(true) } }
    end
  end

  describe '#delete_ineligible_user_assignments_in_batches!' do
    let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let_it_be(:eligible_user) { create(:user) }
    let_it_be(:ineligible_user) { create(:user) }

    subject(:result) { add_on_purchase.delete_ineligible_user_assignments_in_batches! }

    context 'with assigned_users records' do
      before do
        add_on_purchase.assigned_users.create!(user: eligible_user)
        add_on_purchase.assigned_users.create!(user: ineligible_user)
      end

      it 'removes only ineligible user assignments' do
        add_on_purchase.namespace.add_guest(eligible_user)

        expect(add_on_purchase.reload.assigned_users.count).to eq(2)

        expect do
          expect(result).to eq(1)
        end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

        expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
      end

      it 'accepts batch_size and deletes the assignments in batch' do
        expect(GitlabSubscriptions::UserAddOnAssignment).to receive(:pluck_user_ids).twice.and_call_original

        result = add_on_purchase.delete_ineligible_user_assignments_in_batches!(batch_size: 1)

        expect(result).to eq(2)
      end

      it 'expires the cache keys for the ineligible users', :use_clean_rails_redis_caching do
        eligible_user_cache_key = eligible_user.duo_pro_cache_key_formatted
        ineligible_user_cache_key = ineligible_user.duo_pro_cache_key_formatted
        Rails.cache.write(eligible_user_cache_key, true, expires_in: 1.hour)
        Rails.cache.write(ineligible_user_cache_key, true, expires_in: 1.hour)

        add_on_purchase.namespace.add_guest(eligible_user)

        expect(add_on_purchase.reload.assigned_users.count).to eq(2)

        expect { expect(result).to eq(1) }
          .to change { add_on_purchase.reload.assigned_users.count }.by(-1)
          .and change { Rails.cache.read(ineligible_user_cache_key) }.from(true).to(nil)
          .and not_change { Rails.cache.read(eligible_user_cache_key) }
      end

      context 'when the add_on_purchase has no namespace' do
        before do
          add_on_purchase.update_attribute(:namespace, nil)
        end

        context 'when all assigned users are eligible' do
          it { is_expected.to eq(0) }
        end

        context 'when there are ineligible users' do
          it 'removes only ineligible user assignments' do
            ineligible_user.block!

            expect(add_on_purchase.reload.assigned_users.count).to eq(2)

            expect_next_instance_of(::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder) do |finder|
              expect(finder).to receive(:execute).and_call_original
            end

            expect do
              expect(result).to eq(1)
            end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

            expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
          end
        end
      end
    end

    context 'with no assigned_users records' do
      it { is_expected.to eq(0) }

      context 'when add_on_purchase does not have namespace' do
        before do
          add_on_purchase.update!(namespace: nil)
        end

        it { is_expected.to eq(0) }
      end
    end
  end
end
