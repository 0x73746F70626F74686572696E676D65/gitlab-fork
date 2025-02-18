# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ApproveAccessRequestService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:access_requester_user) { create(:user, name: "John Wick") }
  let(:access_requester) { source.requesters.find_by!(user_id: access_requester_user.id) }
  let(:opts) { {} }
  let(:params) { {} }
  let(:access_level_label) { 'Default role: Developer' }
  let(:details) do
    {
      add: 'user_access',
      as: access_level_label,
      member_id: access_requester.id
    }
  end

  shared_examples "auditor with context" do
    it "creates audit event with name" do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: "member_created", target_details: "John Wick", additional_details: details)
      ).and_call_original

      described_class.new(current_user, params).execute(access_requester, **opts)
    end
  end

  context "with auditing" do
    context "for project access" do
      let(:source) { project }

      before do
        project.add_maintainer(current_user)
        project.request_access(access_requester_user)
      end

      it_behaves_like "auditor with context"
    end

    context "for group access" do
      let(:source) { group }

      before do
        group.add_owner(current_user)
        group.request_access(access_requester_user)
      end

      it_behaves_like "auditor with context"
    end
  end

  context 'when current user has admin_group_member custom permission' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group, reload: true) { create(:group) }
    let_it_be(:access_requester_user) { create(:user) }
    let_it_be(:member_role, reload: true) do
      create(:member_role, namespace: group, admin_group_member: true)
    end

    let_it_be(:current_member, reload: true) do
      create(:group_member, :guest, group: group, user: current_user)
    end

    let(:custom_access_level) { Gitlab::Access::MAINTAINER }
    let(:params) { { access_level: role } }

    let(:access_requester) { group.requesters.find_by!(user_id: access_requester_user.id) }

    before do
      group.request_access(access_requester_user)

      # it is more efficient to change the base_access_level than to create a new member_role
      member_role.base_access_level = current_role
      member_role.save!(validate: false)

      current_member.update!(access_level: current_role, member_role: member_role)
      stub_licensed_features(custom_roles: true)
    end

    subject(:approve_access_request) do
      described_class.new(current_user, params).execute(access_requester)
    end

    shared_examples 'updating members using custom permission' do
      context 'when updating member to the same access role as current user' do
        let(:role) { current_role }

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end

        context 'when the custom_roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'raises an error' do
            expect { approve_access_request }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end

      context 'when updating member to higher role than current user' do
        let(:role) { higher_role }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error { Gitlab::Access::AccessDeniedError }
        end
      end
    end

    context 'for guest member role' do
      let(:current_role) { Gitlab::Access::GUEST }
      let(:higher_role) { Gitlab::Access::REPORTER }

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end

    context 'for reporter member role' do
      let(:current_role) { Gitlab::Access::REPORTER }
      let(:higher_role) { Gitlab::Access::DEVELOPER }

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'raises an error' do
          expect { approve_access_request }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end

    context 'for developer member role' do
      let(:current_role) { Gitlab::Access::DEVELOPER }
      let(:higher_role) { Gitlab::Access::MAINTAINER }

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end
      end
    end

    context 'for maintainer member role' do
      let(:current_role) { Gitlab::Access::MAINTAINER }
      let(:higher_role) { Gitlab::Access::OWNER }

      it_behaves_like 'updating members using custom permission'

      context 'with the default (developer) role of the requester' do
        let(:params) { {} }

        it 'approves the request' do
          expect { approve_access_request }.to change { access_requester.reload.requested_at }.to(nil)
        end
      end
    end
  end
end
