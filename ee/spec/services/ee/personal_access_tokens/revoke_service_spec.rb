# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RevokeService, feature_category: :system_access do
  before do
    stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
  end

  let_it_be(:source) { nil }
  let_it_be(:expected_source) { :self }

  describe '#execute' do
    subject { service.execute }

    before do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
    end

    let(:service) { described_class.new(current_user, token: token, group: group, source: source) }

    shared_examples_for 'a successfully revoked token' do
      it { expect(subject.success?).to be true }
      it { expect(service.token.revoked?).to be true }

      it do
        subject
        expect(::Gitlab::Audit::Auditor).to have_received(:audit)
          .with(hash_including(
            name: 'personal_access_token_revoked',
            message: "Revoked personal access token with id #{token.id}",
            additional_details: { revocation_source: expected_source, event_name: "personal_access_token_revoked" }
          ))
      end
    end

    shared_examples_for 'an unsuccessfully revoked token' do
      it { expect(subject.success?).to be false }
      it { expect(service.token.revoked?).to be false }

      it do
        subject
        expect(::Gitlab::Audit::Auditor).to have_received(:audit)
          .with(hash_including(
            name: 'personal_access_token_revoked',
            message: start_with("Attempted to revoke personal access token with id #{token.id}"),
            additional_details: { revocation_source: expected_source, event_name: "personal_access_token_revoked" }
          ))
      end
    end

    context 'managed group' do
      let_it_be(:group) { create(:group_with_managed_accounts) }
      let_it_be(:managed_user) { create(:user, :group_managed, managing_group: group) }
      let_it_be(:group_owner) { create(:user) }
      let_it_be(:group_developer) { create(:user, :group_managed, managing_group: group) }

      before_all do
        group.add_owner(group_owner)
        group.add_developer(group_developer)
      end

      context 'when current user is a managed group owner' do
        let_it_be(:current_user) { group_owner }
        let_it_be(:token) { create(:personal_access_token, user: managed_user) }

        it_behaves_like 'a successfully revoked token'

        context 'and an empty token is given' do
          let_it_be(:token) { nil }

          it { expect(subject.success?).to be false }
        end
      end

      context 'when current user is a group owner of a different managed group' do
        let_it_be(:group) { create(:group_with_managed_accounts) }
        let_it_be(:group_owner2) { create(:user) }
        let_it_be(:current_user) { group_owner2 }
        let_it_be(:token) { create(:personal_access_token, user: managed_user) }

        before_all do
          group.add_owner(group_owner2)
        end

        it_behaves_like 'an unsuccessfully revoked token'
      end

      context 'when current user is not a managed group owner' do
        let_it_be(:current_user) { group_developer }
        let_it_be(:token) { create(:personal_access_token, user: managed_user) }

        it_behaves_like 'an unsuccessfully revoked token'
      end

      context 'when current user is not a managed user' do
        let_it_be(:current_user) { group_owner }
        let_it_be(:token) { create(:personal_access_token, user: create(:user)) }

        it_behaves_like 'an unsuccessfully revoked token'
      end
    end

    context 'when source is not self' do
      let_it_be(:token) { create(:personal_access_token) }
      let_it_be(:current_user) { token.user }
      let_it_be(:source) { :secret_detection }
      let_it_be(:expected_source) { :secret_detection }

      let(:service) { described_class.new(current_user, token: token, source: source) }

      it_behaves_like 'a successfully revoked token'
    end
  end
end
