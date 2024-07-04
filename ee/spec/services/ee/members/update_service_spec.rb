# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::UpdateService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group, :public) }

  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let_it_be_with_refind(:group_member) { create(:group_member, :guest, group: group) }
  let_it_be_with_refind(:project_member) { create(:project_member, :guest, project: project) }

  let(:new_access_level) { Gitlab::Access::GUEST }
  let(:new_expiration) { nil }

  let(:audit_role_from) { "Default role: #{Gitlab::Access.human_access(Gitlab::Access::GUEST)}" }
  let(:audit_role_to) { "Default role: #{Gitlab::Access.human_access(new_access_level)}" }
  let(:audit_role_details) do
    {
      change: 'access_level',
      from: audit_role_from,
      to: audit_role_to,
      expiry_from: nil,
      expiry_to: new_expiration,
      as: audit_role_to,
      member_id: member.id
    }
  end

  let(:current_user) { user }
  let(:member) { group_member }
  let(:params) { { access_level: new_access_level, expires_at: new_expiration } }

  let(:service) { described_class.new(current_user, params) }

  subject(:update_member) { service.execute(member) }

  shared_examples_for 'logs an audit event' do
    specify do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
        name: "member_updated"
      })).and_call_original

      expect { update_member }.to change { AuditEvent.count }.by(1)

      expect(AuditEvent.last).to have_attributes(
        details: hash_including(audit_role_details)
      )
    end
  end

  shared_examples_for 'does not log an audit event' do
    specify do
      expect { update_member }.not_to change { AuditEvent.count }
    end
  end

  shared_examples 'correct member role assignment' do
    it 'returns success' do
      expect(update_member[:status]).to eq(:success)
    end

    it 'assigns the role correctly' do
      expect { update_member }.to change { member.reload.member_role }
        .from(initial_member_role).to(target_member_role)
    end
  end

  shared_examples 'member_promotion_management scenarios' do
    context 'when current_user is an admin' do
      let(:current_user) { admin }

      it 'updates all members', :enable_admin_mode do
        expect(update_members[:status]).to eq(:success)
        expect(update_members[:members]).to match_array(members)
      end
    end

    context 'when current_user is not an admin' do
      let(:current_user) { user }

      before do
        source.add_owner(user)
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        it 'returns an error' do
          allow(Members::MemberApproval).to receive(:create_or_update_pending_approval)
                                              .and_raise(ActiveRecord::RecordInvalid)

          expect { update_members }.not_to change { Members::MemberApproval.count }
          expect(update_members[:status]).to eq(:error)
          expect(update_members[:members].first.errors[:base].first).to eq(
            "Invalid record while queuing users for approval."
          )
          expect(update_members[:members]).to contain_exactly(members.first)
        end
      end

      context 'when current_user can update the given members' do
        it 'queues members requiring promotion management for approval and updates others' do
          expect { update_members }.to change { Members::MemberApproval.count }.by(1)
          expect(update_members[:status]).to eq(:success)
          expect(update_members[:members]).to contain_exactly(members.second)

          members.first.reload
          member_approval = Members::MemberApproval.last
          expect(member_approval.member).to eq(members.first)
          expect(member_approval.member_namespace).to eq(members.first.member_namespace)
          expect(member_approval.old_access_level).to eq(members.first.access_level)
          expect(member_approval.new_access_level).to eq(new_access_level)
          expect(member_approval.requested_by).to eq(current_user)
          expect(update_members[:members_queued_for_approval]).to contain_exactly(member_approval)
        end
      end
    end
  end

  shared_examples 'a service raising Gitlab::Access::AccessDeniedError' do
    it 'when permission denied it raises ::Gitlab::Access::AccessDeniedError' do
      expect { update_member }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end

  context 'when member_promotion_management feature is enabled' do
    let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }

    subject(:update_members) { described_class.new(current_user, params).execute(members) }

    before do
      allow(License).to receive(:current).and_return(ultimate_license)
      stub_feature_flags(member_promotion_management: true)
      stub_application_setting(enable_member_promotion_management: true)
    end

    context 'when user does not have permission to update' do
      let(:current_user) { user }

      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:members) { [project_member] }
      end

      it_behaves_like 'a service raising Gitlab::Access::AccessDeniedError' do
        let(:members) { [group_member] }
      end
    end

    context 'when user have permission to update' do
      let(:new_access_level) { Gitlab::Access::MAINTAINER }

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { project }
        let(:members) { [project_member, create(:project_member, :developer, project: project)] }
      end

      it_behaves_like 'member_promotion_management scenarios' do
        let(:source) { group }
        let(:members) { [group_member, create(:group_member, :developer, group: group)] }
      end
    end
  end

  context 'when current user can update the given member' do
    let(:current_user) { user }

    before_all do
      project.add_maintainer(user)
      group.add_owner(user)
    end

    context 'when there are no new updates to the member' do
      it_behaves_like 'does not log an audit event' do
        let(:member) { group_member }
      end

      it_behaves_like 'does not log an audit event' do
        let(:member) { project_member }
      end
    end

    context 'when a member is updated' do
      let(:member) { group_member }

      context 'when expires_at is updated' do
        let(:new_expiration) { 30.days.from_now.to_date }

        it 'updates the expires_at' do
          expect { update_member }.to change { member.reload.expires_at }
        end

        it_behaves_like 'logs an audit event'
      end

      context 'when access_level is updated' do
        let(:new_access_level) { Gitlab::Access::OWNER }

        it 'updates the access_level' do
          expect { update_member }.to change { member.reload.access_level }
        end

        it_behaves_like 'logs an audit event'
      end
    end

    context 'when updating a member role of a member' do
      let(:member) { group_member }

      let_it_be(:member_role_guest) { create(:member_role, :guest, namespace: group) }
      let_it_be(:member_role_reporter) { create(:member_role, :reporter, namespace: group) }

      let(:params) { { member_role_id: target_member_role&.id } }

      before do
        stub_licensed_features(custom_roles: true)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the member does not have any member role assigned yet' do
        let(:initial_member_role) { nil }
        let(:target_member_role) { member_role_guest }

        let(:audit_role_to) { "Custom role: #{member_role_guest.name}" }
        let(:audit_role_as) { "Custom role: #{member_role_guest.name}" }

        it_behaves_like 'correct member role assignment'

        it_behaves_like 'logs an audit event'
      end

      context 'when the user does not have access to the member role' do
        let(:initial_member_role) { nil }
        let(:target_member_role) { create(:member_role, :guest, namespace: create(:group)) }

        it 'returns not found error' do
          expect(update_member[:status]).to eq(:error)
          expect(update_member[:message]).to eq('Member role not found')
        end
      end

      context 'when assigning the user to an instance-level member role' do
        let(:current_user) { admin }
        let(:initial_member_role) { nil }
        let(:target_member_role) { create(:member_role, :guest, :instance) }

        context 'on self-managed', :enable_admin_mode do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it_behaves_like 'correct member role assignment'
        end
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

        it_behaves_like 'correct member role assignment'

        it_behaves_like 'logs an audit event'

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

        it_behaves_like 'correct member role assignment'
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
