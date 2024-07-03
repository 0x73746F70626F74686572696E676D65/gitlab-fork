# frozen_string_literal: true

require "spec_helper"

RSpec.describe LdapGroupLinksHelper, feature_category: :system_access do
  describe '#ldap_group_link_input_names' do
    subject(:ldap_group_link_input_names) { helper.ldap_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "ldap_group_link[group_access]",
        member_role_id_input_name: "ldap_group_link[member_role_id]"
      }

      expect(ldap_group_link_input_names).to match(hash_including(expected_data))
    end
  end
end
