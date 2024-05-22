# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Entities::MemberRole, feature_category: :permissions do
  describe 'exposes expected fields' do
    let_it_be(:group) { create(:group) }
    let_it_be(:owner) { create(:group_member, :owner, source: group) }

    let(:member_role) { create(:member_role, namespace: group) }
    let(:entity) { described_class.new(member_role) }

    subject { entity.as_json }

    it 'exposes the attributes' do
      expect(subject[:id]).to eq member_role.id
      expect(subject[:name]).to eq member_role.name
      expect(subject[:description]).to eq member_role.description
      expect(subject[:base_access_level]).to eq member_role.base_access_level
      expect(subject[:read_code]).to eq(true)
      expect(subject[:read_vulnerability]).to eq(false)
      expect(subject[:admin_terraform_state]).to eq(false)
      expect(subject[:admin_vulnerability]).to eq(false)
      expect(subject[:manage_group_access_tokens]).to eq(false)
      expect(subject[:manage_project_access_tokens]).to eq(false)
      expect(subject[:archive_project]).to eq(false)
      expect(subject[:remove_project]).to eq(false)
      expect(subject[:group_id]).to eq(group.id)
    end
  end
end
