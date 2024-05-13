# frozen_string_literal: true

require "spec_helper"

RSpec.describe Groups::GroupMembersHelper do
  include MembersPresentation
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(current_user)
  end

  subject do
    helper.group_members_app_data(
      group,
      members: [],
      invited: [],
      access_requests: [],
      banned: banned,
      include_relations: [:inherited, :direct],
      search: nil,
      pending_members: []
    )
  end

  describe '#group_members_app_data' do
    let(:banned) { [] }

    before do
      allow(helper).to receive(:override_group_group_member_path).with(group, ':id').and_return('/groups/foo-bar/-/group_members/:id/override')
      allow(helper).to receive(:group_group_member_path).with(group, ':id').and_return('/groups/foo-bar/-/group_members/:id')
      allow(helper).to receive(:manage_member_roles_path).with(group).and_return(admin_application_settings_roles_and_permissions_path)
      allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(true)
      allow(helper).to receive(:can?).with(current_user, :admin_member_access_request, group).and_return(true)
      allow(helper).to receive(:can?).with(current_user, :export_group_memberships, group).and_return(true)
    end

    it 'adds `ldap_override_path`' do
      expect(subject[:user][:ldap_override_path]).to eq('/groups/foo-bar/-/group_members/:id/override')
    end

    it 'adds `can_export_members`' do
      expect(subject[:can_export_members]).to be true
    end

    it 'adds `export_csv_path`' do
      expect(subject[:export_csv_path]).not_to be_nil
    end

    it 'adds `manage_member_roles_path`' do
      expect(subject[:manage_member_roles_path]).to eq(admin_application_settings_roles_and_permissions_path)
    end

    context 'adds `can_approve_access_requests`' do
      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)

        allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group.root_ancestor) do |instance|
          allow(instance).to receive(:enforce_cap?).and_return(true)
        end
      end

      context 'when namespace has reached the user limit (can not approve accesss requests)' do
        before do
          stub_ee_application_setting(dashboard_limit: 0)
        end

        it 'sets the value to false' do
          expect(subject[:can_approve_access_requests]).to eq(false)
        end
      end

      context 'when namespace has not reached the user limit (can approve access requests)' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)

          allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group.root_ancestor) do |instance|
            allow(instance).to receive(:enforce_cap?).and_return(true)
          end
        end

        it 'sets the value to true' do
          expect(subject[:can_approve_access_requests]).to eq(true)
        end
      end
    end

    context 'adds `namespace_user_limit`' do
      context 'when dashboard limit is set' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)
        end

        it 'sets the value to false' do
          expect(subject[:namespace_user_limit]).to eq(5)
        end
      end

      context 'when dashboard limit is not set' do
        it 'sets the value to false' do
          expect(subject[:namespace_user_limit]).to eq(0)
        end
      end
    end

    describe '`can_filter_by_enterprise`', :saas do
      where(:domain_verification_availabe_for_group, :can_admin_group_member, :expected_value) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
      end

      with_them do
        before do
          stub_licensed_features(domain_verification: domain_verification_availabe_for_group)
          allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(can_admin_group_member)
        end

        it "is set to #{params[:expected_value]}" do
          expect(subject[:can_filter_by_enterprise]).to eq(expected_value)
        end
      end
    end

    context 'banned members' do
      let(:banned) { present_members(create_list(:group_member, 2, group: group, created_by: current_user)) }

      it 'returns `members` property that matches json schema' do
        expect(subject[:banned][:members].to_json).to match_schema('members')
      end

      it 'sets `member_path` property' do
        expect(subject[:banned][:member_path]).to eq('/groups/foo-bar/-/group_members/:id')
      end
    end

    context 'with promotion_request' do
      let(:type) { :for_group_member }
      let(:member_namespace) { group }

      subject(:helper_app_data) do
        helper.group_members_app_data(
          group,
          members: [],
          invited: [],
          access_requests: [],
          banned: banned,
          include_relations: [:inherited, :direct],
          search: nil,
          pending_members: pending_members
        )
      end

      it_behaves_like 'adding promotion_request in app data'
    end
  end

  describe '#group_member_header_subtext' do
    let(:base_subtext) { "You're viewing members of <strong>#{group.name}</strong>." }
    let(:standard_subtext) { "^#{base_subtext}$" }
    let(:enforcement_subtext) { "^#{base_subtext}<br />To manage seats for all members" }

    where(:can_admin_member, :enforce_free_user_cap, :subtext) do
      true  | true  | ref(:enforcement_subtext)
      true  | false | ref(:standard_subtext)
      false | true  | ref(:standard_subtext)
      false | false | ref(:standard_subtext)
    end

    before do
      allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(can_admin_member)
      allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group) do |instance|
        allow(instance).to receive(:enforce_cap?).and_return(enforce_free_user_cap)
      end
    end

    with_them do
      it 'contains expected text' do
        expect(helper.group_member_header_subtext(group)).to match(subtext)
      end
    end
  end

  context 'when member has custom role' do
    let(:member_role) { create(:member_role, :guest, name: 'guest plus', namespace: group, read_code: true, description: 'My custom role') }
    let(:user) { create(:user) }
    let(:banned) { present_members(create_list(:group_member, 1, :guest, group: group, user: user, member_role: member_role)) }

    it 'returns `members` property that matches json schema' do
      expect(subject[:banned][:members].to_json).to match_schema('members')
    end
  end
end
