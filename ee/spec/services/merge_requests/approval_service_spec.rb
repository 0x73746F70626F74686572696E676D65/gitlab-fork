# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalService, feature_category: :code_review_workflow do
  include LoginHelpers

  let_it_be(:user) { create :user }
  let_it_be(:group) { create :group }
  let_it_be(:project) do
    create :project,
      :public,
      :repository,
      group: group,
      approvals_before_merge: 0,
      merge_requests_author_approval: true,
      merge_requests_disable_committers_approval: false
  end

  let_it_be(:merge_request) { create :merge_request_with_diffs, source_project: project, reviewers: [user] }
  let(:enforced_sso) { false }

  subject(:service) { described_class.new(project: project, current_user: user) }

  describe '#execute' do
    before do
      stub_licensed_features merge_request_approvers: true, group_saml: true
      stub_feature_flags ff_require_saml_auth_to_approve: false

      create(:saml_provider, group: project.group, enforced_sso: enforced_sso, enabled: true)
    end

    before_all do
      project.add_developer(user)
      group.add_developer(user)
    end

    def simulate_require_saml_auth_to_approve_mr_approval_setting(restricted: true)
      allow(::Gitlab::Auth::GroupSaml::SsoEnforcer).to(receive(:access_restricted?).and_return(restricted))
    end

    def simulate_saml_approval_in_time?(in_time:)
      allow_next_instances_of(::Gitlab::Auth::GroupSaml::SsoState, 2) do |state|
        allow(state).to receive(:active_since?).and_return(in_time)
      end
    end

    context 'with invalid approval' do
      before do
        allow(merge_request.approvals).to receive(:new).and_return(double(save: false))
      end

      it 'does not reset approvals cache' do
        expect(merge_request).not_to receive(:reset_approval_cache!)

        service.execute(merge_request)
      end
    end

    context 'with valid approval' do
      it 'resets the cache for approvals' do
        expect(merge_request).to receive(:reset_approval_cache!)

        service.execute(merge_request)
      end
    end

    context 'when project requires force auth for approval' do
      before do
        project.update!(require_password_to_approve: true)
      end

      context 'when password not specified' do
        it 'does not update the approvals' do
          expect { service.execute(merge_request) }.not_to change { merge_request.approvals.size }
        end

        context 'when SAML auth is required' do
          let(:enforced_sso) { true }

          before do
            simulate_require_saml_auth_to_approve_mr_approval_setting(restricted: true)
          end

          context 'without ff_require_saml_auth_to_approve feature flag' do
            it 'does not change approval count' do
              expect { service.execute(merge_request) }.not_to change { merge_request.approvals.size }
            end
          end

          context 'with ff_require_saml_auth_to_approve feature flag' do
            before do
              stub_feature_flags ff_require_saml_auth_to_approve: group
            end

            # passes when run with :focus flaky when without
            xit 'approves when in time' do
              simulate_require_saml_auth_to_approve_mr_approval_setting
              simulate_saml_approval_in_time? in_time: true
              allow_next_instances_of(ApprovalState, 2) do |approval_state|
                allow(approval_state).to receive(:eligible_for_approval_by?).and_return(true)
              end
              expect { service.execute(merge_request) }.to change { merge_request.approvals.size }
            end

            it 'does not approve when not in time' do
              expect { service.execute(merge_request) }.not_to change { merge_request.approvals.size }
            end
          end
        end
      end

      context 'when incorrect password is specified' do
        let(:params) do
          { approval_password: 'incorrect' }
        end

        it 'does not update the approvals' do
          service_with_params = described_class.new(project: project, current_user: user, params: params)

          expect { service_with_params.execute(merge_request) }.not_to change { merge_request.approvals.size }
        end
      end

      context 'when correct password is specified' do
        let(:params) do
          { approval_password: user.password }
        end

        it 'approves the merge request' do
          service_with_params = described_class.new(project: project, current_user: user, params: params)

          expect { service_with_params.execute(merge_request) }.to change { merge_request.approvals.size }
        end

        context 'when SAML auth is required' do
          let(:enforced_sso) { true }

          context 'without ff_require_saml_auth_to_approve feature flag' do
            it 'changes approval count' do
              simulate_require_saml_auth_to_approve_mr_approval_setting(restricted: false)

              service_with_params = described_class.new(project: project, current_user: user, params: params)

              expect { service_with_params.execute(merge_request) }.to change { merge_request.approvals.size }
            end
          end

          context 'with ff_require_saml_auth_to_approve feature flag' do
            before do
              stub_feature_flags ff_require_saml_auth_to_approve: group
            end

            it 'does not change approval count' do
              simulate_require_saml_auth_to_approve_mr_approval_setting

              service_with_params = described_class.new(project: project, current_user: user, params: params)

              expect { service_with_params.execute(merge_request) }.not_to change { merge_request.approvals.size }
            end

            it 'changes approval count' do
              simulate_require_saml_auth_to_approve_mr_approval_setting(restricted: false)
              simulate_saml_approval_in_time?(in_time: true)

              service_with_params = described_class.new(project: project, current_user: user, params: params)

              expect { service_with_params.execute(merge_request) }.to change { merge_request.approvals.size }
            end
          end
        end
      end
    end
  end

  describe '#execute with instance saml' do
    let(:access_restricted) { true }
    # if password auth is allowed, instance SAML is not enforced via SSOEnforcer
    let(:password_authentication_enabled_for_web) { false }

    before do
      stub_licensed_features merge_request_approvers: true
      stub_application_setting password_authentication_enabled_for_web: password_authentication_enabled_for_web

      stub_omniauth_saml_config(
        enabled: true,
        auto_link_saml_user: false,
        allow_single_sign_on: ['saml'],
        providers: [mock_saml_config]
      )
    end

    before_all do
      project.add_developer(user)
      group.add_developer(user)
    end

    def simulate_require_saml_auth_to_approve(restricted: true)
      allow_next_instances_of(::Gitlab::Auth::Saml::SsoEnforcer, 1) do |enforcer|
        allow(enforcer).to receive(:access_restricted?).and_return(restricted)
      end
    end

    def simulate_instance_saml_approval_in_time?(in_time:)
      allow_next_instances_of(::Gitlab::Auth::Saml::SsoState, 2) do |state|
        allow(state).to receive(:active_since?).and_return(in_time)
      end
    end

    it 'changes approval count' do
      simulate_require_saml_auth_to_approve(restricted: access_restricted)
      simulate_instance_saml_approval_in_time?(in_time: true)
      expect { service.execute(merge_request) }.to change { merge_request.approvals.size }
    end
  end
end
