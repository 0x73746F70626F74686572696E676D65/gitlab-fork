# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:namespace) { create(:group) }

    subject(:execute) { described_class.new(namespace).execute }

    context 'when add_on is not available' do
      it { is_expected.to be_empty }
    end

    context 'when add_on is available' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }

      context 'with non trial add_on_purchase' do
        context 'with active add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, trial: true).execute }

            it { is_expected.to be_empty }
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end

        context 'with expired add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to be_empty }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, trial: true).execute }

            it { is_expected.to be_empty }
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end
      end

      context 'with trial add_on_purchase' do
        context 'with active add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, trial: true).execute }

            it { is_expected.to match_array([add_on_purchase]) }

            context 'when filtering by any active state' do
              subject(:execute) { described_class.new(namespace, only_active: false).execute }

              it { is_expected.to match_array([add_on_purchase]) }
            end
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end

        context 'with expired add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :expired_trial, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to be_empty }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, trial: true).execute }

            it { is_expected.to be_empty }

            context 'when filtering by any active state' do
              subject(:execute) { described_class.new(namespace, trial: true, only_active: false).execute }

              it { is_expected.to match_array([add_on_purchase]) }
            end
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end
      end
    end
  end
end
