# frozen_string_literal: true

require "spec_helper"

RSpec.describe SamlGroupLinksHelper, feature_category: :system_access do
  let_it_be(:group) { create_default(:group) }
  let_it_be(:user) { create_default(:user) }
  let_it_be(:member_role) { create_default(:member_role, namespace: group) }
  let_it_be(:saml_group_link) { create_default(:saml_group_link, group: group, member_role: member_role) }

  describe '#saml_group_link_role_selector_data', :saas, feature_category: :permissions do
    let(:expected_standard_role_data) { { standard_roles: group.access_level_roles } }
    let(:expected_custom_role_data) do
      { custom_roles: [{ member_role_id: member_role.id,
                         name: member_role.name,
                         base_access_level: member_role.base_access_level }] }
    end

    subject(:data) { helper.saml_group_link_role_selector_data(group, user) }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'returns a hash with the expected standard and custom role data' do
      expect(data).to eq(expected_standard_role_data.merge(expected_custom_role_data))
    end

    context 'when custom roles are not enabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns a hash with the expected standard role data' do
        expect(data).to eq(expected_standard_role_data)
      end
    end
  end

  describe '#saml_group_link_role_name' do
    subject { helper.saml_group_link_role_name(saml_group_link) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when a member role is present' do
      it { is_expected.to eq(member_role.name) }
    end

    context 'when a member role is not present' do
      let_it_be(:saml_group_link) { create_default(:saml_group_link, group: group, member_role: nil) }

      it { is_expected.to eq('Guest') }
    end

    context 'when custom roles are disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it { is_expected.to eq('Guest') }
    end
  end

  describe '#saml_group_link_input_names' do
    subject(:saml_group_link_input_names) { helper.saml_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "saml_group_link[access_level]",
        member_role_id_input_name: "saml_group_link[member_role_id]"
      }

      expect(saml_group_link_input_names).to match(hash_including(expected_data))
    end
  end
end
