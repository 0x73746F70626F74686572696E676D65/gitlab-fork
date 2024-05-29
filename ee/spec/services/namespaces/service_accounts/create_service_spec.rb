# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::CreateService, feature_category: :user_management do
  shared_examples 'service account creation failure' do
    it 'produces an error', :aggregate_failures do
      result = service.execute

      expect(result.status).to eq(:error)
      expect(result.message).to eq(
        s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
      )
    end
  end

  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }

  let(:namespace_id) { group.id }

  subject(:service) do
    described_class.new(current_user, { organization_id: organization.id, namespace_id: namespace_id })
  end

  context 'when self-managed' do
    before do
      stub_licensed_features(service_accounts: true)
      allow(License).to receive(:current).and_return(license)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      context 'when subscription is of starter plan' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it 'raises error' do
          result = service.execute

          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available to create Service Account User')
        end
      end

      context 'when subscription is ultimate tier' do
        let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group.id}" }
        end

        it 'sets provisioned by group' do
          result = service.execute
          expect(result.payload.provisioned_by_group_id).to eq(group.id)
        end

        context 'when the group is invalid' do
          let(:namespace_id) { non_existing_record_id }

          it_behaves_like 'service account creation failure'
        end

        context 'when the group is subgroup' do
          let(:namespace_id) { subgroup.id }

          it_behaves_like 'service account creation failure'
        end
      end

      context 'when subscription is of premium tier' do
        let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
        let_it_be(:service_account1) { create(:user, :service_account, provisioned_by_group_id: group.id) }
        let_it_be(:service_account2) { create(:user, :service_account, provisioned_by_group_id: group.id) }

        context 'when premium seats are not available' do
          before do
            allow(license).to receive(:restricted_user_count).and_return(1)
          end

          it 'raises error' do
            result = service.execute

            expect(result.status).to eq(:error)
            expect(result.message).to include('No more seats are available to create Service Account User')
          end
        end

        context 'when premium seats are available' do
          before do
            allow(license).to receive(:restricted_user_count).and_return(User.service_account.count + 2)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          it 'sets provisioned by group' do
            result = service.execute

            expect(result.payload.provisioned_by_group_id).to eq(group.id)
          end

          context 'when the group is invalid' do
            let(:namespace_id) { non_existing_record_id }

            it_behaves_like 'service account creation failure'
          end

          context 'when the group is subgroup' do
            let(:namespace_id) { subgroup.id }

            it_behaves_like 'service account creation failure'
          end
        end
      end
    end

    context 'when current user is not an admin' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      context "when not a group owner" do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account creation failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        it_behaves_like 'service account creation failure'
      end
    end
  end

  context 'when saas', :saas do
    before do
      stub_licensed_features(service_accounts: true)
      create(:gitlab_subscription, namespace: group, hosted_plan: hosted_plan)
      stub_application_setting(check_namespace_plan: true)
    end

    shared_examples 'creates service accounts as per subscription' do
      context 'when subscription is of free plan' do
        let(:hosted_plan) { create(:free_plan) }

        it_behaves_like 'service account creation failure'
      end

      context 'when subscription is ultimate tier' do
        let(:hosted_plan) { create(:ultimate_plan) }

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group.id}" }
        end

        it 'sets provisioned by group' do
          result = service.execute
          expect(result.payload.provisioned_by_group_id).to eq(group.id)
        end

        context 'when the group is invalid' do
          let(:namespace_id) { non_existing_record_id }

          it_behaves_like 'service account creation failure'
        end

        context 'when the group is subgroup' do
          let(:namespace_id) { subgroup.id }

          it_behaves_like 'service account creation failure'
        end
      end

      context 'when subscription is of premium tier' do
        let_it_be(:hosted_plan) { create(:premium_plan) }
        let_it_be(:service_account1) { create(:user, :service_account, provisioned_by_group_id: group.id) }
        let_it_be(:service_account2) { create(:user, :service_account, provisioned_by_group_id: group.id) }

        context 'when premium seats are not available' do
          before do
            group.gitlab_subscription.update!(seats: 1)
          end

          it 'raises error' do
            result = service.execute

            expect(result.status).to eq(:error)
            expect(result.message).to include(
              s_('ServiceAccount|No more seats are available to create Service Account User')
            )
          end
        end

        context 'when premium seats are available' do
          before do
            group.gitlab_subscription.update!(seats: 4)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          it 'sets provisioned by group' do
            result = service.execute

            expect(result.payload.provisioned_by_group_id).to eq(group.id)
          end

          context 'when the group is invalid' do
            let(:namespace_id) { non_existing_record_id }

            it_behaves_like 'service account creation failure'
          end

          context 'when the group is subgroup' do
            let(:namespace_id) { subgroup.id }

            it_behaves_like 'service account creation failure'
          end
        end
      end
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like "creates service accounts as per subscription"
    end

    context 'when current user is not an admin' do
      let(:hosted_plan) { create(:ultimate_plan) }

      context 'when not a group owner' do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account creation failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        it_behaves_like "creates service accounts as per subscription"
      end
    end
  end
end
