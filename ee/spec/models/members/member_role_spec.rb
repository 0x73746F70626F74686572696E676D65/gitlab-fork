# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MemberRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:members) }
    it { is_expected.to have_many(:saml_providers) }
    it { is_expected.to have_many(:saml_group_links) }
  end

  describe 'validation' do
    subject(:member_role) { build(:member_role) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:base_access_level) }
    it { is_expected.to validate_inclusion_of(:base_access_level).in_array(described_class::LEVELS) }

    context 'when running on Gitlab.com', :saas do
      it { is_expected.to validate_presence_of(:namespace) }
    end

    context 'when running on self-managed' do
      it { is_expected.not_to validate_presence_of(:namespace) }
    end

    context 'for base_access_level_locked' do
      before do
        member_role.base_access_level = ProjectMember::GUEST
        member_role.read_vulnerability = true
        member_role.save!

        member_role.read_vulnerability = false
        member_role.name = 'new name'
        member_role.description = 'new description'
      end

      it 'cannot be saved when base_access_level has changes' do
        member_role.base_access_level = ProjectMember::DEVELOPER

        expect(member_role).not_to be_valid
        expect(member_role.errors.messages[:base_access_level]).to include(
          s_('MemberRole|cannot be changed. Please create a new Member Role instead.')
        )
      end

      it 'can be changed when only name, description and permissions change' do
        expect(member_role).to be_valid
      end
    end

    context 'when not assigned to member' do
      it 'can be changed' do
        expect(member_role).to be_valid
      end
    end

    context 'for max_count_per_group_hierarchy' do
      let_it_be(:group) { create(:group) }

      subject(:member_role) { build(:member_role, namespace: group) }

      context 'when number of member roles is below limit' do
        it 'is valid' do
          is_expected.to be_valid
        end
      end

      context 'when number of member roles is above limit' do
        before do
          stub_const('MemberRole::MAX_COUNT_PER_GROUP_HIERARCHY', 1)
          create(:member_role, namespace: group)
          group.reload
        end

        it 'is invalid' do
          is_expected.to be_invalid
        end
      end
    end

    context 'when for namespace' do
      let_it_be(:root_group) { create(:group) }

      context 'when namespace is a subgroup' do
        it 'is invalid' do
          subgroup = create(:group, parent: root_group)
          member_role.namespace = subgroup

          expect(member_role).to be_invalid
          expect(member_role.errors[:namespace]).to include(
            s_("MemberRole|must be top-level namespace")
          )
        end
      end

      context 'when namespace is a root group' do
        it 'is valid' do
          member_role.namespace = root_group

          expect(member_role).to be_valid
        end
      end

      context 'when namespace is outside hierarchy of member' do
        it 'creates a validation error' do
          member_role.save!
          member_role.namespace = create(:group)

          expect(member_role).not_to be_valid
          expect(member_role.errors[:namespace]).to include(s_("MemberRole|can't be changed"))
        end
      end

      context 'when base_access_level is invalid' do
        it 'raises an error' do
          member_role.base_access_level = 11

          expect(member_role).not_to be_valid
          expect(member_role.errors[:base_access_level])
            .to include("is not included in the list")
        end
      end

      context 'when requirement is not met' do
        it 'creates a validation error' do
          member_role.base_access_level = Gitlab::Access::GUEST
          member_role.admin_vulnerability = true

          expect(member_role).not_to be_valid
          expect(member_role.errors[:base])
            .to include(s_("MemberRole|Read vulnerability has to be enabled in order to enable Admin vulnerability"))
        end
      end
    end
  end

  describe 'callbacks' do
    context 'for preventing deletion after member is associated' do
      let_it_be_with_reload(:member_role) { create(:member_role) }

      subject(:destroy_member_role) { member_role.destroy } # rubocop: disable Rails/SaveBang

      it 'allows deletion without any member associated' do
        expect(destroy_member_role).to be_truthy
      end

      it 'prevent deletion when member is associated' do
        create(:group_member, { group: member_role.namespace,
                                access_level: Gitlab::Access::DEVELOPER,
                                member_role: member_role })
        member_role.members.reload

        expect(destroy_member_role).to be_falsey
        expect(member_role.errors.messages[:base])
          .to(
            include(s_(
              "MemberRole|Role is assigned to one or more group members. " \
              "Remove role from all group members, then delete role."
            ))
          )
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member_role_1) { create(:member_role, name: 'Tester', namespace: group) }
    let_it_be(:member_role_2) { create(:member_role, name: 'Manager', namespace: group) }
    let_it_be(:group_2_member_role) { create(:member_role, name: 'Actor') }

    describe '.elevating' do
      it 'creates proper query' do
        allow(described_class).to receive(:all_customizable_permissions).and_return(
          read_code: { description: 'Permission to read code', skip_seat_consumption: true },
          see_code: { description: 'Test permission' }
        )

        expect(described_class.elevating.to_sql).to include('WHERE (see_code = true)')
      end

      it 'creates proper query with multiple permissions' do
        allow(described_class).to receive(:all_customizable_permissions).and_return(
          read_code: { description: 'Permission to read code', skip_seat_consumption: true },
          see_code: { description: 'Test permission', skip_seat_consumption: false },
          remove_code: { description: 'Test second permission' }
        )

        expect(described_class.elevating.to_sql).to include('WHERE (see_code = true OR remove_code = true)')
      end

      it 'returns nothing when there are no elevating permissions' do
        create(:member_role)

        expect(described_class.elevating).to be_empty
      end
    end

    describe 'by_namespace' do
      it 'returns member roles for a group' do
        expect(described_class.by_namespace(group)).to match_array([member_role_1, member_role_2])
      end
    end

    describe 'for_instance' do
      let_it_be(:instance_member_role) { create(:member_role, :instance, name: 'Manager') }

      it 'returns member roles created on the instance' do
        expect(described_class.for_instance).to match_array([instance_member_role])
      end
    end

    describe '.with_members_count' do
      let_it_be(:member_role_1_members) do
        create_list(:group_member, 3, :developer, {
          member_role: member_role_1,
          source: group
        })
      end

      let_it_be(:member_role_2_members) do
        create_list(:group_member, 2, :developer, {
          member_role: member_role_2,
          source: group
        })
      end

      it 'returns the total count of members for each role' do
        expect(described_class.with_members_count.map { |x| [x.id, x.members_count] }).to match_array([
          [member_role_1.id, 3],
          [member_role_2.id, 2],
          [group_2_member_role.id, 0]
        ])
      end
    end
  end

  describe '.levels_sentence' do
    it 'returns the list of access levels with names' do
      expect(described_class.levels_sentence).to eq(
        "10 (Guest), 20 (Reporter), 30 (Developer), 40 (Maintainer), and 50 (Owner)"
      )
    end
  end

  describe 'covering all permissions columns' do
    it 'has all attributes listed in the member_roles table' do
      expect(described_class.attribute_names.map(&:to_sym))
        .to contain_exactly(*described_class.all_customizable_permissions.keys,
          *described_class::NON_PERMISSION_COLUMNS)
    end
  end

  describe '#enabled_permissions' do
    it 'returns the list of enabled abilities' do
      member_role = build_stubbed(:member_role, read_code: true, read_vulnerability: true, read_dependency: false)

      expect(member_role.enabled_permissions).to match_array([:read_code, :read_vulnerability])
    end
  end

  shared_examples 'ability with the correct `available_from_access_level` attribute' do |policy_class|
    where(:role, :level) { Gitlab::Access.sym_options_with_owner.to_a }

    with_them do
      before do
        stub_member_access_level(object, role => user)
        stub_licensed_features(security_dashboard: true)
      end

      let(:policy) { policy_class.new(user, object) }

      it 'gives access from the specified access level' do
        abilities.each do |ability|
          if ability[:available_from_access_level] > level
            expect(policy).to be_disallowed(ability[:name])
          else
            expect(policy).to be_allowed(ability[:name])
          end
        end
      end
    end
  end

  describe 'available_from_access_level for abilities' do
    let_it_be(:user) { build_stubbed(:user) }

    context 'for group abilities' do
      let_it_be(:object) { build_stubbed(:group) }
      let_it_be(:abilities) do
        described_class.all_customizable_permissions.select do |_k, v|
          v[:group_ability] && v[:available_from_access_level]
        end.values
      end

      it_behaves_like 'ability with the correct `available_from_access_level` attribute', GroupPolicy
    end

    context 'for project abilities' do
      let_it_be(:object) { build_stubbed(:project) }
      let_it_be(:abilities) do
        described_class.all_customizable_permissions.select do |_k, v|
          v[:project_ability] && v[:available_from_access_level]
        end.values
      end

      it_behaves_like 'ability with the correct `available_from_access_level` attribute', ProjectPolicy
    end
  end
end
