# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::UpdateService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:member_users) { create_list(:user, 2) }
  let_it_be(:access_level) { Gitlab::Access::MAINTAINER }
  let(:permission) { :update }
  let(:expiration) { 2.days.from_now }
  let(:original_access_level) { Gitlab::Access::DEVELOPER }
  let(:member) { source.members_and_requesters.find_by!(user_id: member_users.first.id) }
  let(:params) do
    { access_level: access_level, expires_at: expiration }
  end

  let(:members) { source.members_and_requesters.where(user_id: member_users).to_a }
  let(:update_service) { described_class.new(current_user, params) }

  let(:audit_role_expiration_from) { nil }
  let(:audit_role_from) { "Default role: #{Gitlab::Access.human_access(original_access_level)}" }
  let(:audit_role_to) { "Default role: #{Gitlab::Access.human_access(access_level)}" }
  let(:audit_role_details) do
    {
      change: 'access_level',
      from: audit_role_from,
      to: audit_role_to,
      expiry_from: audit_role_expiration_from,
      expiry_to: expiration.to_date,
      as: audit_role_to,
      member_id: member.id
    }
  end

  shared_examples_for 'logs an audit event' do
    specify do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: "member_updated", additional_details: audit_role_details)
      ).and_call_original

      expect do
        described_class.new(current_user, params).execute(member, permission: permission)
      end.to change { AuditEvent.count }.by(1)
    end
  end

  shared_examples_for 'does not log an audit event' do
    specify do
      expect do
        described_class.new(current_user, params).execute(member, permission: permission)
      end.not_to change { AuditEvent.count }
    end
  end

  shared_examples 'member_promotion_management scenarios' do
    context 'when current_user is an admin' do
      let(:current_user) { create(:admin) }

      it 'updates all members' do
        allow(current_user).to receive(:can_admin_all_resources?).and_return(true)
        result = update_service.execute(members, permission: permission)

        expect(result[:status]).to eq(:success)
        expect(result[:members]).to match_array(members)
      end
    end

    context 'when current_user is not an admin' do
      before do
        source.add_guest(member_users.first)

        source.add_developer(member_users.second)
        create(:user_highest_role, :developer, user: member_users.second)
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        it 'returns an error' do
          allow(members.first).to receive(:queue_for_approval).and_raise(ActiveRecord::RecordInvalid)

          result = update_service.execute(members, permission: permission)

          expect(result[:status]).to eq(:error)
          expect(result[:members]).to contain_exactly(members.first)
        end
      end

      context 'when current_user can update the given members' do
        it 'queues members requiring promotion management for approval and updates others' do
          result = update_service.execute(members, permission: permission)

          expect(result[:status]).to eq(:success)
          expect(result[:members]).to contain_exactly(members.second)

          member_approval = Members::MemberApproval.last
          expect(member_approval.member).to eq(members.first)
          expect(member_approval.member_namespace).to eq(members.first.member_namespace)
          expect(member_approval.old_access_level).to eq(members.first.access_level)
          expect(member_approval.new_access_level).to eq(access_level)
          expect(member_approval.requested_by).to eq(current_user)
          expect(result[:members_queued_for_approval]).to contain_exactly(member_approval)
        end
      end
    end
  end

  shared_examples 'a service raising Gitlab::Access::AccessDeniedError' do
    before do
      member_users.each do |member_user|
        source.add_guest(member_user)
      end
    end

    it 'when permission denied it raises ::Gitlab::Access::AccessDeniedError' do
      expect { update_service.execute(members, permission: permission) }
        .to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when member_promotion_management feature is enabled' do
    let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }

    before do
      allow(License).to receive(:current).and_return(ultimate_license)
      stub_feature_flags(member_promotion_management: true)
      stub_application_setting(enable_member_promotion_management: true)
    end

    context 'when user does not have permission to update' do
      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:source) { project }
      end

      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:source) { group }
      end
    end

    context 'when user have permission to update' do
      before do
        source.add_owner(current_user)
      end

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { project }
      end

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { group }
      end
    end
  end

  context 'when current user can update the given member' do
    before_all do
      project.add_developer(member_users.first)
      group.add_developer(member_users.first)

      project.add_maintainer(current_user)
      group.add_owner(current_user)
    end

    it_behaves_like 'logs an audit event' do
      let(:source) { project }
    end

    it_behaves_like 'logs an audit event' do
      let(:source) { group }
    end

    context 'when the update is a noOp' do
      subject(:service) { described_class.new(current_user, params) }

      before do
        service.execute(member, permission: permission)
      end

      it_behaves_like 'does not log an audit event' do
        let(:source) { group }
      end

      it_behaves_like 'does not log an audit event' do
        let(:source) { project }
      end

      context 'when access_level remains the same and expires_at changes' do
        let(:expiration_from) { 24.days.from_now }
        let(:original_access_level) { Gitlab::Access::MAINTAINER }

        let(:audit_role_expiration_from) { expiration_from.to_date }

        before do
          described_class.new(
            current_user,
            params.merge(expires_at: expiration_from)
          ).execute(member, permission: permission)
        end

        it_behaves_like 'logs an audit event' do
          let(:source) { group }
        end
      end

      context 'when expires_at remains the same and access_level changes' do
        before do
          described_class.new(
            current_user,
            params.merge(access_level: original_access_level)
          ).execute(member, permission: permission)
        end

        let(:original_access_level) { Gitlab::Access::OWNER }
        let(:audit_role_expiration_from) { expiration.to_date }

        it_behaves_like 'logs an audit event' do
          let(:source) { group }
        end
      end
    end

    context 'when updating a member role of a member' do
      let_it_be(:member, reload: true) { create(:group_member, :guest, group: group) }
      let_it_be(:member_role_guest) { create(:member_role, :guest, namespace: group) }
      let_it_be(:member_role_reporter) { create(:member_role, :reporter, namespace: group) }

      let(:params) { { expires_at: expiration, member_role_id: target_member_role&.id } }
      let(:original_access_level) { Gitlab::Access::GUEST }

      subject(:update_member) { described_class.new(current_user, params).execute(member) }

      before do
        stub_licensed_features(custom_roles: true)
      end

      shared_examples 'correct member role assignement' do
        it 'returns success' do
          expect(update_member[:status]).to eq(:success)
        end

        it 'assigns the role correctly' do
          expect { update_member }.to change { member.reload.member_role }
            .from(initial_member_role).to(target_member_role)
        end
      end

      context 'when the member does not have any member role assigned yet' do
        let(:initial_member_role) { nil }
        let(:target_member_role) { member_role_guest }

        let(:audit_role_to) { "Custom role: #{member_role_guest.name}" }
        let(:audit_role_as) { "Custom role: #{member_role_guest.name}" }

        it_behaves_like 'correct member role assignement'

        it_behaves_like 'logs an audit event' do
          let(:source) { group }
        end
      end

      context 'when the user does not have access to the member role' do
        let(:initial_member_role) { nil }
        let(:target_member_role) { create(:member_role, :guest, namespace: create(:group)) }

        it 'returns error' do
          expect(update_member[:status]).to eq(:error)
          expect(update_member[:message]).to eq(
            'Member namespace must be in same hierarchy as custom role\'s namespace'
          )
        end
      end

      context 'when assigning the user to an instance-level member role' do
        let(:initial_member_role) { nil }
        let(:target_member_role) { create(:member_role, :guest, :instance) }

        it_behaves_like 'correct member role assignement'
      end

      context 'when the member has a member role assigned' do
        before do
          member.update!(member_role: initial_member_role)
        end

        let(:initial_member_role) { member_role_guest }
        let(:target_member_role) { member_role_reporter }

        let(:audit_role_from) { "Custom role: #{member_role_guest.name}" }
        let(:audit_role_to) { "Custom role: #{member_role_reporter.name}" }
        let(:audit_role_as) { "Custom role: #{member_role_reporter.name}" }

        it_behaves_like 'correct member role assignement'

        it_behaves_like 'logs an audit event' do
          let(:source) { group }
        end

        it 'changes the access level of the member accordingly' do
          update_member

          expect(member.reload.access_level).to eq(target_member_role.base_access_level)
        end

        context 'when invalid access_level is provided' do
          let(:params) { { member_role_id: target_member_role&.id, access_level: GroupMember::DEVELOPER } }

          it 'returns error' do
            expect(update_member[:status]).to eq(:error)
          end
        end
      end

      context 'when downgrading to static role' do
        before do
          member.update!(member_role: initial_member_role)
        end

        let(:initial_member_role) { member_role_guest }
        let(:target_member_role) { nil }

        it_behaves_like 'correct member role assignement'
      end
    end
  end

  context 'when current user has admin_group_member custom permission' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:root_ancestor, reload: true) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_ancestor) }
    let_it_be(:current_member, reload: true) { create(:group_member, group: root_ancestor, user: current_user) }
    let_it_be(:member_role, reload: true) do
      create(:member_role, namespace: root_ancestor, admin_group_member: true)
    end

    let(:params) { { access_level: role } }

    subject(:update_member) do
      described_class.new(current_user, params).execute(member)
    end

    shared_examples 'updating members using custom permission' do
      let_it_be(:member, reload: true) do
        create(:group_member, :minimal_access, group: group)
      end

      before do
        # it is more efficient to change the base_access_level than to create a new member_role
        member_role.base_access_level = current_role
        member_role.save!(validate: false)

        current_member.update!(access_level: current_role, member_role: member_role)
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when updating member to the same access role as current user' do
          let(:role) { current_role }

          it 'updates the member' do
            expect { update_member }.to change { member.access_level }.to(role)
          end
        end

        context 'when updating member to higher role than current user' do
          let(:role) { higher_role }

          it 'raises an error' do
            expect { update_member }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        context 'when updating member to the same access role as current user' do
          let(:role) { current_role }

          it 'fails to update the member' do
            expect { update_member }.to raise_error { Gitlab::Access::AccessDeniedError }
          end
        end
      end
    end

    shared_examples 'updating members using custom permission in a group' do
      context 'for guest member role' do
        let(:current_role) { Gitlab::Access::GUEST }
        let(:higher_role) { Gitlab::Access::REPORTER }

        it_behaves_like 'updating members using custom permission'

        context 'when downgrading member role' do
          let(:member) { create(:group_member, :maintainer, group: group) }
          let(:role) { Gitlab::Access::REPORTER }

          before do
            stub_licensed_features(custom_roles: true)

            # it is more efficient to change the base_access_level than to create a new member_role
            member_role.base_access_level = current_role
            member_role.save!(validate: false)

            current_member.update!(access_level: current_role, member_role: member_role)
          end

          it 'updates the member' do
            expect { update_member }.to change { member.access_level }.to(role)
          end
        end
      end

      context 'for reporter member role' do
        let(:current_role) { Gitlab::Access::REPORTER }
        let(:higher_role) { Gitlab::Access::DEVELOPER }

        it_behaves_like 'updating members using custom permission'
      end

      context 'for developer member role' do
        let(:current_role) { Gitlab::Access::DEVELOPER }
        let(:higher_role) { Gitlab::Access::MAINTAINER }

        it_behaves_like 'updating members using custom permission'
      end

      context 'for maintainer member role' do
        let(:current_role) { Gitlab::Access::MAINTAINER }
        let(:higher_role) { Gitlab::Access::OWNER }

        it_behaves_like 'updating members using custom permission'
      end
    end

    context 'when updating a member of the root group' do
      let_it_be(:group) { root_ancestor }

      it_behaves_like 'updating members using custom permission in a group'
    end

    context 'when updating a member of the subgroup' do
      let_it_be(:group) { subgroup }

      it_behaves_like 'updating members using custom permission in a group'
    end
  end
end
