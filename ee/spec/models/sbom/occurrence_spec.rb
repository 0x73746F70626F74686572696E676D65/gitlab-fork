# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Occurrence, type: :model, feature_category: :dependency_management do
  let_it_be(:occurrence) { build(:sbom_occurrence) }

  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to belong_to(:component_version) }
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:source) }
    it { is_expected.to belong_to(:source_package) }
    it { is_expected.to have_many(:occurrences_vulnerabilities) }
    it { is_expected.to have_many(:vulnerabilities) }
  end

  describe 'loose foreign key on sbom_occurrences.pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:sbom_occurrence, pipeline: parent) }
    end
  end

  describe 'validations' do
    subject { build(:sbom_occurrence) }

    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }
    it { is_expected.to validate_length_of(:package_manager).is_at_most(255) }
    it { is_expected.to validate_length_of(:component_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:input_file_path).is_at_most(1024) }

    describe '#licenses' do
      subject { build(:sbom_occurrence, licenses: licenses) }

      let(:apache) do
        {
          spdx_identifier: 'Apache-2.0',
          name: 'Apache License 2.0',
          url: 'http://spdx.org/licenses/Apache-2.0.html'
        }
      end

      let(:mit) do
        {
          spdx_identifier: 'MIT',
          name: 'MIT License',
          url: 'http://spdx.org/licenses/MIT.html'
        }
      end

      context 'when licenses is empty' do
        let(:licenses) { [] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has a single valid license' do
        let(:licenses) { [mit] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has multiple valid licenses' do
        let(:licenses) { [apache, mit] }

        it { is_expected.to be_valid }
      end

      context 'when spdx_identifier is missing' do
        let(:licenses) { [mit.except(:spdx_identifier)] }

        it { is_expected.to be_invalid }
      end

      context 'when spdx_identifier is blank' do
        let(:licenses) { [mit.merge(spdx_identifier: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when spdx_identifier is too long' do
        # max length derived from `pm_licenses`.`spdx_identifier` column
        let(:licenses) { [mit.merge(spdx_identifier: 'X' * 51)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license name is missing' do
        let(:licenses) { [mit.except(:name)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license name is blank' do
        let(:licenses) { [mit.merge(name: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license url is missing' do
        let(:licenses) { [mit.except(:url)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license url is blank' do
        let(:licenses) { [mit.merge(url: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license contains unknown properties' do
        let(:licenses) { [mit.merge(unknown: 'value')] }

        it { is_expected.to be_invalid }
      end
    end
  end

  describe '.filter_by_components scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'returns occurrences matching the given components' do
      expect(described_class.filter_by_components([matching_occurrence.component])).to eq([matching_occurrence])
    end

    it 'returns occurrences matching the given component ids' do
      expect(described_class.filter_by_components([matching_occurrence.component.id])).to eq([matching_occurrence])
    end
  end

  describe '.with_component_source_version_and_project scope' do
    let_it_be(:occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'pre-loads relations to avoid executing additional queries' do
      record = described_class.with_component_source_version_and_project.first

      queries = ActiveRecord::QueryRecorder.new do
        record.component
        record.component_version
        record.source
        record.project
      end

      expect(queries.count).to be_zero
    end
  end

  describe '.with_pipeline_project_and_namespace' do
    before do
      create(:sbom_occurrence, component: create(:sbom_component))
    end

    it 'preloads the pipeline, project, and namespace associations' do
      record = described_class.with_pipeline_project_and_namespace.first

      queries = ActiveRecord::QueryRecorder.new do
        record.pipeline.project.namespace
      end

      expect(queries.count).to be_zero
    end
  end

  describe '.filter_by_non_nil_component_version scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component_version: nil) }

    it 'returns occurrences with a non-nil component_version' do
      expect(described_class.filter_by_non_nil_component_version).to eq([matching_occurrence])
    end
  end

  describe '.order_by_id' do
    let_it_be(:first) { create(:sbom_occurrence) }
    let_it_be(:second) { create(:sbom_occurrence) }

    it 'returns records sorted by id' do
      expect(described_class.order_by_id).to eq([first, second])
    end
  end

  describe '.order_by_component_name' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_1')) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_2')) }

    it 'returns records sorted by component name asc' do
      expect(described_class.order_by_component_name('asc').map(&:name)).to eq(%w[component_1 component_2])
    end

    it 'returns records sorted by component name desc' do
      expect(described_class.order_by_component_name('desc').map(&:name)).to eq(%w[component_2 component_1])
    end
  end

  describe '.order_by_package_name' do
    let_it_be(:occurrence_nuget_a) { create(:sbom_occurrence, component_name: 'component-a', packager_name: 'nuget') }
    let_it_be(:occurrence_nuget_b) { create(:sbom_occurrence, component_name: 'component-b', packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    subject(:relation) { described_class.order_by_package_name(order) }

    context 'when the sort order is ascending' do
      let(:order) { 'asc' }

      it 'returns records sorted by package name asc, component name asc' do
        expect(relation.to_a).to eq([occurrence_npm, occurrence_nuget_a, occurrence_nuget_b, occurrence_null])
      end
    end

    context 'when the sort order is descending' do
      let(:order) { 'desc' }

      it 'returns records sorted by package name desc, component name asc' do
        expect(relation.to_a).to eq([occurrence_null, occurrence_nuget_a, occurrence_nuget_b, occurrence_npm])
      end
    end
  end

  describe '.order_by_spdx_identifier' do
    let_it_be(:mit_occurrence) { create(:sbom_occurrence, :mit) }
    let_it_be(:apache_occurrence) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:apache_and_mpl_occurrence) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:apache_and_mit_occurrence) { create(:sbom_occurrence, :apache_2, :mit) }
    let_it_be(:mit_and_mpl_occurrence) { create(:sbom_occurrence, :mit, :mpl_2) }

    subject(:relation) { described_class.order_by_spdx_identifier(order) }

    context 'when sorting in ascending order' do
      let(:order) { 'asc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          apache_and_mit_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          mit_occurrence.licenses
        ])
      end
    end

    context 'when sorting in descending order' do
      let(:order) { 'desc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          mit_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_and_mit_occurrence.licenses
        ])
      end
    end
  end

  describe '.order_by_severity' do
    let_it_be(:occurrence_critical) { create(:sbom_occurrence, highest_severity: :critical) }
    let_it_be(:occurrence_low) { create(:sbom_occurrence, highest_severity: :low) }

    it 'returns records sorted by highest_severity asc' do
      expect(described_class.order_by_severity('asc').map(&:highest_severity)).to eq(%w[low critical])
    end

    it 'returns records sorted by highest_severity desc' do
      expect(described_class.order_by_severity('desc').map(&:highest_severity)).to eq(%w[critical low])
    end
  end

  describe '.filter_by_component_names' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component name' do
      expect(described_class.filter_by_component_names([occurrence_1.name])).to eq([occurrence_1])
    end
  end

  describe '.filter_by_source_types' do
    let_it_be(:container_scanning_occurrence) { create(:sbom_occurrence, :os_occurrence) }
    let_it_be(:dependency_scanning_occurrence) { create(:sbom_occurrence) }

    it 'returns records filtered by source name' do
      expect(described_class.filter_by_source_types([:container_scanning])).to eq([container_scanning_occurrence])
    end
  end

  describe '.by_licenses' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:occurrence_1) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :mit) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:occurrence_5) { create(:sbom_occurrence) }

    where(:input, :expected) do
      %w[MIT MPL-2.0]     | [ref(:occurrence_2), ref(:occurrence_3), ref(:occurrence_4)]
      %w[MPL-2.0 unknown] | [ref(:occurrence_3), ref(:occurrence_4), ref(:occurrence_5)]
      %w[unknown]         | [ref(:occurrence_5)]
      []                  | []
    end

    with_them do
      it 'returns expected output for each input' do
        expect(described_class.by_licenses(input)).to match_array(expected)
      end
    end
  end

  describe '.by_primary_license' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:occurrence_1) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :mit) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:occurrence_5) { create(:sbom_occurrence) }

    where(:input, :expected) do
      %w[MIT MPL-2.0]     | [ref(:occurrence_2), ref(:occurrence_3)]
      %w[MPL-2.0 unknown] | [ref(:occurrence_3), ref(:occurrence_5)]
      %w[unknown]         | [ref(:occurrence_5)]
      []                  | []
    end

    with_them do
      it 'returns expected output for each input' do
        expect(described_class.by_primary_license(input)).to match_array(expected)
      end
    end
  end

  describe '.unarchived' do
    let_it_be(:unarchived_occurrence) { create(:sbom_occurrence) }

    before_all do
      create(:sbom_occurrence, project: create(:project, :archived))
    end

    it 'returns only unarchived occurrences' do
      expect(described_class.unarchived).to eq([unarchived_occurrence])
    end
  end

  describe '.by_project_ids' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by project_id' do
      expect(described_class.by_project_ids(occurrence_1.project)).to eq([occurrence_1])
    end
  end

  describe '.by_uuids' do
    let_it_be(:occurrences) { create_list(:sbom_occurrence, 2) }

    specify { expect(described_class.by_uuids(occurrences.first.uuid)).to eq([occurrences.first]) }
  end

  describe '.filter_by_package_managers' do
    let_it_be(:occurrence_nuget) { create(:sbom_occurrence, packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    it 'returns records filtered by package name' do
      expect(described_class.filter_by_package_managers(%w[npm])).to eq([occurrence_npm])
    end

    context 'with empty array' do
      it 'returns no records' do
        expect(described_class.filter_by_package_managers([])).to eq([])
      end
    end
  end

  describe '.filter_by_search_with_component_and_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, project: project) }
    let_it_be(:source_npm) { occurrence_npm.source }
    let_it_be(:component_version) { occurrence_npm.component_version }
    let_it_be(:source_bundler) { create(:sbom_source, packager_name: 'bundler', input_file_path: 'Gemfile.lock') }
    let_it_be(:occurrence_bundler) do
      create(:sbom_occurrence, source: source_bundler, component_version: component_version, project: project)
    end

    context 'with different search keywords' do
      using RSpec::Parameterized::TableSyntax

      where(:keyword, :occurrences) do
        'file'  | [ref(:occurrence_bundler)]
        'pack'  | [ref(:occurrence_npm)]
        'lock'  | [ref(:occurrence_npm), ref(:occurrence_bundler)]
        '_'     | []
      end

      with_them do
        it 'returns records filtered by search' do
          result = described_class.filter_by_search_with_component_and_group(keyword, component_version.id, group)

          expect(result).to eq(occurrences)
        end
      end
    end

    context 'with no search keyword' do
      let_it_be(:occurrence_bundler_with_no_source) do
        create(:sbom_occurrence, source: nil, component_version: component_version, project: project)
      end

      let(:keyword) { nil }

      it 'returns all relevant records' do
        result = described_class.filter_by_search_with_component_and_group(keyword, component_version.id, group)

        expect(result).to match_array([occurrence_npm, occurrence_bundler, occurrence_bundler_with_no_source])
      end
    end

    context 'with unrelated group' do
      let_it_be(:unrelated_group) { create(:group) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', component_version.id, unrelated_group)
      end

      it { is_expected.to be_empty }
    end

    context 'with unrelated component' do
      let_it_be(:unrelated_component_version) { create(:sbom_component_version) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', unrelated_component_version.id, group)
      end

      it { is_expected.to be_empty }
    end
  end

  describe ".with_licenses" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject { described_class.with_licenses }

    context "without occurrences" do
      it { is_expected.to be_empty }
    end

    context "without a license" do
      let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }

      it { is_expected.to be_empty }
    end

    context "with occurrences" do
      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :mpl_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }
      let_it_be(:occurrence_5) { create(:sbom_occurrence, :mit, :mpl_2, project: project) }
      let_it_be(:occurrence_6) { create(:sbom_occurrence, :apache_2, :mit, project: project) }
      let_it_be(:occurrence_7) { create(:sbom_occurrence, project: project) }

      it "returns an occurrence for each unique license" do
        expect(subject.pluck(:spdx_identifier)).to eq([
          "MIT",
          "MPL-2.0",
          "Apache-2.0",
          "Apache-2.0", "MPL-2.0",
          "MIT", "MPL-2.0",
          "Apache-2.0", "MIT"
        ])
      end
    end
  end

  describe ".visible_to" do
    subject(:visible_to) { described_class.visible_to(user) }

    let_it_be(:group_a) { create(:group) }
    let_it_be(:group_b) { create(:group) }
    let_it_be(:group_c) { create(:group) }
    let_it_be(:project_a) { create(:project, group: group_a) }
    let_it_be(:project_b) { create(:project, group: group_b) }
    let_it_be(:project_c) { create(:project, group: group_c) }

    let_it_be(:occurrence_a) { create(:sbom_occurrence, project: project_a) }
    let_it_be(:occurrence_b) { create(:sbom_occurrence, project: project_b) }
    let_it_be(:occurrence_c) { create(:sbom_occurrence, project: project_c) }

    context "when admin", :enable_admin_mode do
      let_it_be(:user) { create(:user, :admin) }

      it "returns all occurrences" do
        expect(subject).to match_array([
          occurrence_a,
          occurrence_b,
          occurrence_c
        ])
      end
    end

    context "when a direct member" do
      using RSpec::Parameterized::TableSyntax

      where(:role, :resources, :expected_occurrences) do
        :guest | [ref(:project_a)] | [ref(:occurrence_a)]
        :reporter | [ref(:group_a)] | [ref(:occurrence_a)]
        :developer | [ref(:project_a), ref(:project_c)] | [ref(:occurrence_a), ref(:occurrence_c)]
        :developer | [ref(:group_a)] | [ref(:occurrence_a)]
        :developer | [ref(:group_a), ref(:project_b)] | [ref(:occurrence_a), ref(:occurrence_b)]
        :maintainer | [ref(:project_b)] | [ref(:occurrence_b)]
        :owner | [ref(:group_a)] | [ref(:occurrence_a)]
      end

      with_them do
        let(:user) { create(:user) }

        before do
          resources.each do |resource|
            resource.add_member(user, role)
          end
        end

        it { is_expected.to match_array(expected_occurrences) }
      end
    end

    context "when a member of a custom role with :read_dependency enabled" do
      let_it_be(:user) { create(:user) }
      let_it_be(:role) { create(:member_role, :read_dependency, namespace: group_a) }

      context "on a project level" do
        let_it_be(:membership) { create(:project_member, :guest, source: project_b, member_role: role, user: user) }

        it { is_expected.to match_array([occurrence_b]) }
      end

      context "on a group level" do
        let_it_be(:membership) { create(:group_member, :guest, source: group_a, member_role: role, user: user) }

        it { is_expected.to match_array([occurrence_a]) }
      end

      context "when the role is not assigned" do
        it { is_expected.to be_empty }
      end
    end
  end

  describe 'group related scopes' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group_1) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: parent_group) }
    let_it_be(:child_group_1_1) { create(:group, parent: child_group_1) }

    let_it_be(:project_on_parent) { create(:project, group: parent_group) }
    let_it_be(:project_on_child_1) { create(:project, group: child_group_1) }
    let_it_be(:project_on_child_2) { create(:project, :archived, group: child_group_2) }
    let_it_be(:project_on_child_1_1) { create(:project, group: child_group_1_1) }

    let_it_be(:occurrence_on_project_on_parent) { create(:sbom_occurrence, project: project_on_parent) }
    let_it_be(:occurrence_on_project_on_child_1) { create(:sbom_occurrence, project: project_on_child_1) }
    let_it_be(:another_occurrence_on_project_on_child_1) { create(:sbom_occurrence, project: project_on_child_1) }
    let_it_be(:occurrence_on_project_on_child_2) { create(:sbom_occurrence, project: project_on_child_2) }
    let_it_be(:occurrence_on_project_on_child_1_1) { create(:sbom_occurrence, project: project_on_child_1_1) }

    describe '.in_parent_group_after_and_including' do
      subject { described_class.in_parent_group_after_and_including(another_occurrence_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          another_occurrence_on_project_on_child_1,
          occurrence_on_project_on_child_2,
          occurrence_on_project_on_child_1_1
        ])
      end
    end

    describe '.in_parent_group_before_and_including' do
      subject { described_class.in_parent_group_before_and_including(another_occurrence_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          occurrence_on_project_on_parent,
          occurrence_on_project_on_child_1,
          another_occurrence_on_project_on_child_1
        ])
      end
    end

    describe '.order_traversal_ids_asc' do
      subject { described_class.order_traversal_ids_asc }

      it do
        is_expected.to eq([
          occurrence_on_project_on_parent,
          occurrence_on_project_on_child_1,
          another_occurrence_on_project_on_child_1,
          occurrence_on_project_on_child_1_1,
          occurrence_on_project_on_child_2
        ])
      end
    end
  end

  describe '#name' do
    let(:component) { build(:sbom_component, name: 'rails') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates name to component' do
      expect(occurrence.name).to eq('rails')
    end
  end

  describe '#version' do
    let(:component_version) { build(:sbom_component_version, version: '6.1.6.1') }
    let(:occurrence) { build(:sbom_occurrence, component_version: component_version) }

    it 'delegates version to component_version' do
      expect(occurrence.version).to eq('6.1.6.1')
    end

    context 'when component_version is nil' do
      let(:occurrence) { build(:sbom_occurrence, component_version: nil) }

      it 'returns nil' do
        expect(occurrence.version).to be_nil
      end
    end
  end

  describe '#purl_type' do
    let(:component) { build(:sbom_component, purl_type: 'npm') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates purl_type to component' do
      expect(occurrence.purl_type).to eq('npm')
    end
  end

  describe '#component_type' do
    let(:component) { build(:sbom_component, component_type: 'library') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates component_type to component' do
      expect(occurrence.component_type).to eq('library')
    end
  end

  describe 'source delegation' do
    let(:source_attributes) do
      {
        'category' => 'development',
        'input_file' => { 'path' => 'package-lock.json' },
        'source_file' => { 'path' => 'package.json' },
        'package_manager' => { 'name' => 'npm' },
        'language' => { 'name' => 'JavaScript' }
      }
    end

    let(:source) { build(:sbom_source, source: source_attributes) }
    let(:occurrence) { build(:sbom_occurrence, source: source) }

    describe '#packager' do
      subject(:packager) { occurrence.packager }

      it 'delegates packager to source' do
        expect(packager).to eq('npm')
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it { is_expected.to be_nil }
      end
    end

    describe '#location' do
      subject(:location) { occurrence.location }

      it 'returns expected location data' do
        expect(location).to eq(
          {
            blob_path: "/#{occurrence.project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.input_file_path}",
            path: occurrence.input_file_path,
            top_level: false,
            ancestors: []
          }
        )
      end

      context 'when ancestors is present' do
        let(:ancestors) { [{ 'name' => 'name', 'version' => 'version' }] }
        let(:occurrence) { build(:sbom_occurrence, source: source, ancestors: ancestors) }

        it 'returns location data including ancestors' do
          expect(location[:ancestors]).to eq(ancestors)
        end
      end

      context 'when occurrence was found by trivy' do
        before do
          occurrence.input_file_path = 'container-image:photon:5.1-12345678'
        end

        it 'returns expected location data' do
          expect(location).to eq(
            {
              blob_path: "/#{occurrence.project.full_path}/-/blob/#{occurrence.commit_sha}/" \
                         "#{occurrence.input_file_path}",
              path: occurrence.input_file_path,
              top_level: false,
              ancestors: []
            }
          )
        end
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it 'returns nil values' do
          expect(location).to eq(
            {
              blob_path: nil,
              path: nil,
              top_level: false,
              ancestors: []
            }
          )
        end
      end
    end
  end
end
