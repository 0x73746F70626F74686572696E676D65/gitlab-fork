# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::DeleteService, feature_category: :user_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:delete_user) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:error_message) { s_ "ServiceAccount|User does not have permission to delete a service account." }
  let_it_be(:options) { { hard_delete: false } }

  subject(:service) { described_class.new(current_user, delete_user) }

  RSpec.shared_examples 'service account deletion is success' do
    it 'deletes a service account successfully', :sidekiq_inline do
      result = perform_enqueued_jobs { service.execute(options) }

      expect(result.status).to eq(:success)
      expect(Users::GhostUserMigration.where(user: delete_user, initiator_user: current_user)).to exist
      expect(delete_user.reload.blocked?).to eq(true)
    end
  end

  RSpec.shared_examples 'service account deletion failure' do
    it 'delete service account fails', :aggregate_failures do
      result = perform_enqueued_jobs { service.execute(options) }

      expect(result.status).to eq(:error)
      expect(result.message).to eq(error_message)
      expect(Users::GhostUserMigration.where(user: delete_user, initiator_user: current_user)).not_to exist
      expect(delete_user.reload.blocked?).to eq(false)
    end
  end

  context 'when self-managed' do
    before do
      stub_licensed_features(service_accounts: true)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'service account deletion is success'

      context 'when user to be deleted is not of type service account' do
        let_it_be(:delete_user) { create(:user) }

        before_all do
          group.add_maintainer(delete_user)
        end

        it_behaves_like 'service account deletion failure'
      end
    end

    context 'when current user is not an admin' do
      context "when not a group owner" do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account deletion failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        it_behaves_like 'service account deletion failure'
      end
    end
  end

  context 'when saas', :saas do
    before do
      stub_licensed_features(service_accounts: true)
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'service account deletion is success'

        context 'when user to be deleted is not of type service account' do
          let_it_be(:delete_user) { create(:user) }

          before_all do
            group.add_maintainer(delete_user)
          end

          it_behaves_like 'service account deletion failure'
        end
      end
    end

    context 'when current user is not an admin' do
      context 'when not a group owner' do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account deletion failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        it_behaves_like 'service account deletion is success'

        context 'when user to be deleted is not of type service account' do
          let_it_be(:delete_user) { create(:user) }

          before_all do
            group.add_maintainer(delete_user)
          end

          it_behaves_like 'service account deletion failure'
        end
      end
    end
  end
end
