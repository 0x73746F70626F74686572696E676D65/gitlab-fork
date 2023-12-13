# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::CreateService, feature_category: :system_access do
  shared_examples_for 'an unsuccessfully created token' do
    it { expect(create_token.success?).to be false }
    it { expect(create_token.message).to eq('Not permitted to create') }
    it { expect(token).to be_nil }
  end

  describe '#execute' do
    subject(:create_token) { service.execute }

    let(:target_user) { create(:user) }
    let(:service) do
      described_class.new(current_user: current_user, target_user: target_user,
        params: params, concatenate_errors: false)
    end

    let(:valid_params) do
      { name: 'Test token', impersonation: false, scopes: [:api], expires_at: Date.today + 1.month }
    end

    let(:token) { create_token.payload[:personal_access_token] }

    let(:max_personal_access_token_lifetime) do
      PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS.days.from_now.to_date
    end

    context 'when expires_at is nil', :enable_admin_mode do
      let(:params) { valid_params.merge(expires_at: nil) }
      let(:current_user) { create(:admin) }
      let(:instance_level_pat_expiration_date) { 30.days.from_now.to_date }
      let(:group_level_pat_expiration_policy) { 20 }
      let(:group_level_max_expiration_date) { Date.current + group_level_pat_expiration_policy }

      context 'when expiration policy is licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when instance level expiration date is set' do
          before do
            stub_ee_application_setting(
              max_personal_access_token_lifetime_from_now: instance_level_pat_expiration_date
            )
          end

          it { expect(token.expires_at).to eq instance_level_pat_expiration_date }
        end

        context 'when group level expiration is set' do
          let(:group) do
            build(:group_with_managed_accounts, max_personal_access_token_lifetime: group_level_pat_expiration_policy)
          end

          context 'when user is group managed' do
            let(:target_user) { create(:user, managing_group: group) }

            it { expect(token.expires_at).to eq group_level_max_expiration_date }
          end

          context 'when user is not group managed' do
            it 'sets expires_at to default value' do
              expect(token.expires_at)
              .to eq max_personal_access_token_lifetime
            end
          end
        end

        context 'when neither instance level nor group level expiration is set' do
          it "sets expires_at to default value" do
            expect(token.expires_at)
            .to eq max_personal_access_token_lifetime
          end
        end
      end

      context 'when expiration policy is not licensed' do
        it "sets expires_at to default value" do
          expect(token.expires_at)
          .to eq max_personal_access_token_lifetime
        end
      end
    end

    context 'when target user is a service account', :freeze_time do
      let(:target_user) { create(:user, :service_account) }

      context 'for instance level' do
        let(:params) { valid_params }

        context 'when the current user is an admin' do
          let(:current_user) { create(:admin) }

          it_behaves_like 'an unsuccessfully created token'

          context 'when admin mode enabled', :enable_admin_mode do
            it_behaves_like 'an unsuccessfully created token'

            context 'when the feature is licensed' do
              before do
                stub_licensed_features(service_accounts: true)
              end

              it 'creates a token successfully' do
                expect(create_token.success?).to be true
              end

              context 'when expires_at is nil' do
                let(:params) { valid_params.merge(expires_at: nil) }

                context 'when service_access_tokens_expiration_enforced is false' do
                  before do
                    stub_ee_application_setting(service_access_tokens_expiration_enforced: false)
                  end

                  it { expect(token.expires_at).to be_nil }
                end

                it "sets expires_at to default value when setting is true" do
                  expect(token.expires_at)
                  .to eq max_personal_access_token_lifetime
                end
              end
            end
          end
        end
      end

      context 'for a group' do
        let(:params) { valid_params.merge(group: group) }
        let(:group) { create(:group) }
        let(:current_user) { create(:user) }

        context 'when current user is a group owner' do
          before do
            group.add_owner(current_user)
          end

          context 'when the feature is licensed' do
            before do
              stub_licensed_features(service_accounts: true)
            end

            context 'when provisioned by group' do
              before do
                target_user.provisioned_by_group_id = group.id
                target_user.save!
              end

              it 'creates a token successfully' do
                expect(create_token.success?).to be true
              end

              context 'when expires_at is nil' do
                let(:params) { valid_params.merge(group: group, expires_at: nil) }

                context 'when saas', :saas, :enable_admin_mode do
                  context 'when service_access_tokens_expiration_enforced is false' do
                    before do
                      group.namespace_settings.update!(service_access_tokens_expiration_enforced: false)
                    end

                    it { expect(create_token.payload[:personal_access_token].expires_at).to be_nil }
                  end

                  context 'when service_access_tokens_expiration_enforced is true' do
                    it {
                      expect(create_token.payload[:personal_access_token].expires_at)
                    .to eq max_personal_access_token_lifetime
                    }
                  end
                end

                context 'when not saas' do
                  it "does not set expires_at to be nil" do
                    expect(create_token.payload[:personal_access_token].expires_at)
                    .to eq max_personal_access_token_lifetime
                  end
                end
              end
            end

            context 'when not provisioned by group' do
              it_behaves_like 'an unsuccessfully created token'
            end
          end

          context 'when feature is not licensed' do
            before do
              stub_licensed_features(service_accounts: false)
            end

            it_behaves_like 'an unsuccessfully created token'
          end
        end

        context 'when current user is not a group owner' do
          before do
            group.add_guest(current_user)
            stub_licensed_features(service_accounts: true)
          end

          it_behaves_like 'an unsuccessfully created token'
        end
      end
    end
  end
end
