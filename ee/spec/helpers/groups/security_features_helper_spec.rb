# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SecurityFeaturesHelper do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group, refind: true) { create(:group) }
  let_it_be(:user, refind: true) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
    allow(helper).to receive(:can?).and_return(false)
  end

  describe '#group_level_security_dashboard_available?' do
    where(:group_level_compliance_dashboard_enabled, :read_group_compliance_dashboard_permission, :result) do
      false | false | false
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(group_level_compliance_dashboard: group_level_compliance_dashboard_enabled)
        allow(helper).to receive(:can?).with(user, :read_group_compliance_dashboard, group).and_return(read_group_compliance_dashboard_permission)
      end

      it 'returns the expected result' do
        expect(helper.group_level_compliance_dashboard_available?(group)).to eq(result)
      end
    end
  end

  describe '#group_level_credentials_inventory_available?' do
    where(:credentials_inventory_feature_enabled, :enforced_group_managed_accounts, :read_group_credentials_inventory_permission, :result) do
      true  | false | false | false
      true  | true  | false | false
      true  | false | true  | false
      true  | true  | true  | true
      false | false | false | false
      false | false | false | false
      false | false | true  | false
      false | true  | true  | false
    end

    with_them do
      before do
        stub_licensed_features(credentials_inventory: credentials_inventory_feature_enabled)
        allow(group).to receive(:enforced_group_managed_accounts?).and_return(enforced_group_managed_accounts)
        allow(helper).to receive(:can?).with(user, :read_group_credentials_inventory, group).and_return(read_group_credentials_inventory_permission)
      end

      it 'returns the expected result' do
        expect(helper.group_level_credentials_inventory_available?(group)).to eq(result)
      end
    end
  end

  describe '#group_level_security_dashboard_data' do
    subject { helper.group_level_security_dashboard_data(group) }

    before do
      allow(helper).to receive(:current_user).and_return(:user)
      allow(helper).to receive(:can?).and_return(true)
    end

    let(:has_projects) { 'false' }
    let(:dismissal_descriptions_json) do
      Gitlab::Json.parse(fixture_file('vulnerabilities/dismissal_descriptions.json', dir: 'ee')).to_json
    end

    let(:expected_data) do
      {
        projects_endpoint: "http://localhost/api/v4/groups/#{group.id}/projects",
        group_full_path: group.full_path,
        no_vulnerabilities_svg_path: helper.image_path('illustrations/empty-state/empty-search-md.svg'),
        empty_state_svg_path: helper.image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        security_dashboard_empty_svg_path: helper.image_path('illustrations/empty-state/empty-secure-md.svg'),
        vulnerabilities_export_endpoint: "/api/v4/security/groups/#{group.id}/vulnerability_exports",
        can_admin_vulnerability: 'true',
        can_view_false_positive: 'false',
        has_projects: has_projects,
        dismissal_descriptions: dismissal_descriptions_json
      }
    end

    context 'when it does not have projects' do
      it { is_expected.to eq(expected_data) }
    end

    context 'when it has projects' do
      let(:has_projects) { 'true' }

      before do
        create(:project, :public, group: group)
      end

      it { is_expected.to eq(expected_data) }
    end

    context 'when it does not have projects but has subgroups that do' do
      let(:subgroup) { create(:group, parent: group) }
      let(:has_projects) { 'true' }

      before do
        create(:project, :public, group: subgroup)
      end

      it { is_expected.to eq(expected_data) }
    end
  end

  describe '#group_security_discover_data' do
    let_it_be(:group) { create(:group) }

    let(:content) { 'discover-group-security' }

    let(:expected_group_security_discover_data) do
      {
        group: {
          id: group.id,
          name: group.name
        },
        link: {
          main: new_trial_registration_path(glm_source: 'gitlab.com', glm_content: content),
          secondary: group_billings_path(group.root_ancestor, source: content)
        }
      }
    end

    subject(:group_security_discover_data) do
      helper.group_security_discover_data(group)
    end

    it 'builds correct hash' do
      expect(group_security_discover_data).to eq(expected_group_security_discover_data)
    end
  end
end
