# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::Enforcement, :saas, feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  using RSpec::Parameterized::TableSyntax

  describe '.enforceable_storage_limit', :freeze_time do
    where(:enforcement_limit, :dashboard_limit, :dashboard_limit_enabled_at, :group_created_at, :result) do
      # no limits apply
      0   | 0   | nil          | 1.month.ago  | 0
      0   | 0   | Time.current | 1.month.ago  | 0
      0   | 0   | 1.month.ago  | Time.current | 0

      # enforcement limit applies
      100 | 0   | nil          | 1.month.ago  | 100
      100 | 0   | Time.current | 1.month.ago  | 100
      100 | 50  | Time.current | 1.month.ago  | 100
      100 | 500 | Time.current | 1.month.ago  | 100

      # dashboard limit applies
      0   | 50  | nil          | 1.month.ago  | 0
      0   | 50  | 1.month.ago  | Time.current | 50
      100 | 50  | 1.month.ago  | Time.current | 50
      25  | 50  | 1.month.ago  | Time.current | 50
      0   | 50  | Time.current | 1.month.ago  | 0
    end

    with_them do
      let(:group) { create(:group_with_plan, created_at: group_created_at) }

      before do
        plan_limit = create(
          :plan_limits,
          enforcement_limit: enforcement_limit,
          storage_size_limit: dashboard_limit,
          dashboard_limit_enabled_at: dashboard_limit_enabled_at
        )

        group.gitlab_subscription.update!(hosted_plan: plan_limit.plan)
      end

      it 'returns the expected limit' do
        expect(described_class.enforceable_storage_limit(group)).to eq result
      end
    end
  end

  describe '.enforce_limit?' do
    before do
      stub_feature_flags(namespace_storage_limit: group)
      stub_application_setting(
        enforce_namespace_storage_limit: true,
        automatic_purchased_storage_allocation: true
      )
    end

    let_it_be(:group, refind: true) { create(:group_with_plan) }
    let_it_be(:subgroup, refind: true) { create(:group, parent: group) }

    subject(:enforce_limit?) { described_class.enforce_limit?(group) }

    context 'with plans and exclusions' do
      where(:plan, :enforcement_limit, :dashboard_limit, :excluded, :result) do
        :free_plan       | 100 | 0   | false | true
        :free_plan       | 0   | 0   | false | false
        :free_plan       | 0   | 100 | false | true
        :free_plan       | 100 | 100 | false | true
        :free_plan       | 0   | 0   | true  | false
        :free_plan       | 100 | 0   | true  | false
        :free_plan       | 0   | 100 | true  | false
        :free_plan       | 100 | 100 | true  | false

        # paid plans are not enforced
        :ultimate_plan   | 100 | 0   | false | false
        :ultimate_plan   | 0   | 100 | false | false
        :ultimate_plan   | 100 | 100 | false | false
        :ultimate_plan   | 100 | 0   | true  | false
        :ultimate_plan   | 0   | 100 | true  | false
        :ultimate_plan   | 100 | 100 | true  | false

        # opensource plans are not enforced
        :opensource_plan | 100 | 0   | false | false
        :opensource_plan | 0   | 100 | false | false
        :opensource_plan | 100 | 100 | false | false
        :opensource_plan | 100 | 0   | true  | false
        :opensource_plan | 0   | 100 | true  | false
        :opensource_plan | 100 | 100 | true  | false
      end

      with_them do
        before do
          plan_limit = create(
            :plan_limits,
            plan,
            enforcement_limit: enforcement_limit,
            storage_size_limit: dashboard_limit,
            dashboard_limit_enabled_at: group.created_at - 1.day
          )

          group.root_ancestor.gitlab_subscription.update!(hosted_plan: plan_limit.plan)

          create(:namespace_storage_limit_exclusion, namespace: group.root_ancestor) if excluded
        end

        it 'returns the expected result' do
          expect(enforce_limit?).to eq result
        end

        context 'with a subgroup' do
          it 'returns the expected result' do
            expect(described_class.enforce_limit?(subgroup)).to eq result
          end
        end

        context 'with disabled settings' do
          it 'returns false when the namespace_storage_limit feature flag is disabled' do
            stub_feature_flags(namespace_storage_limit: false)

            expect(enforce_limit?).to eq(false)
          end

          it 'returns false when the enforce_namespace_storage_limit application setting is disabled' do
            stub_application_setting(enforce_namespace_storage_limit: false)

            expect(enforce_limit?).to eq(false)
          end

          it 'returns false when the automatic_purchased_storage_allocation application setting is disabled' do
            stub_application_setting(automatic_purchased_storage_allocation: false)

            expect(enforce_limit?).to eq(false)
          end
        end
      end
    end

    context 'when the group does not have a plan' do
      let_it_be(:group, refind: true) { create(:group) }
      let_it_be(:plan_limit) { create(:plan_limits, :free_plan, enforcement_limit: 100) }

      context 'when enforcement limit is set on the free plan' do
        it { is_expected.to be true }
      end

      context 'when enforcement limit is not set on the free plan' do
        before do
          plan_limit.update!(enforcement_limit: 0)
        end

        it { is_expected.to be false }
      end
    end
  end

  describe '.show_pre_enforcement_alert?' do
    subject(:show_pre_enforcement_alert?) { described_class.show_pre_enforcement_alert?(group) }

    let_it_be(:group) { create(:group_with_plan, :with_root_storage_statistics, plan: :free_plan) }

    context 'with application settings set to false' do
      context 'when should_check_namespace_plan? is false' do
        before do
          allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(false)
        end

        it 'returns false' do
          expect(show_pre_enforcement_alert?).to eq(false)
        end
      end
    end

    context 'with application settings set to true' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(true)
      end

      context 'when the namespace reaches the notification limit' do
        before do
          allow(described_class).to receive(:reached_pre_enforcement_notification_limit?).and_return(true)
        end

        it 'returns true' do
          expect(show_pre_enforcement_alert?).to eq(true)
        end
      end
    end
  end

  describe '.reached_pre_enforcement_notification_limit?' do
    let(:root_namespace) { create(:group_with_plan, :with_root_storage_statistics, plan: :free_plan) }

    subject(:reached_pre_enforcement_notification_limit?) do
      described_class.reached_pre_enforcement_notification_limit?(root_namespace)
    end

    context 'when storage limit exclusion is present' do
      let!(:excluded_namespace) { create(:namespace_storage_limit_exclusion, namespace: root_namespace) }

      it 'returns false' do
        expect(reached_pre_enforcement_notification_limit?).to be false
      end
    end

    context 'when storage limit exclusion is not present' do
      where(:total_storage, :notification_limit, :additional_purchased_storage_size, :expected_result) do
        12 | 0  | 0     | false
        12 | 13 | 0     | false
        12 | 12 | 0     | true
        13 | 12 | 0     | true
        12 | 13 | 1024  | false
        13 | 12 | 1024  | true
        15 | 13 | 1024  | true
        12 | 12 | 1024  | false
      end

      with_them do
        before do
          root_namespace.update!(additional_purchased_storage_size: additional_purchased_storage_size)
          set_used_storage(root_namespace, megabytes: total_storage)
          set_notification_limit(root_namespace, megabytes: notification_limit)
        end

        it 'returns expected_result' do
          expect(reached_pre_enforcement_notification_limit?).to eq(expected_result)
        end
      end
    end
  end
end
