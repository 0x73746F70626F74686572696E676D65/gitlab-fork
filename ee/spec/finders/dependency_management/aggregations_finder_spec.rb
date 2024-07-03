# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::AggregationsFinder, feature_category: :dependency_management do
  let_it_be(:target_group) { create(:group) }
  let(:params) { {} }
  let_it_be(:subgroup) { create(:group, parent: target_group) }
  let_it_be(:outside_group) { create(:group) }
  let_it_be(:outside_project) { create(:project, group: outside_group) }
  let_it_be(:archived_project) { create(:project, :archived, group: target_group) }

  let_it_be(:target_projects) do
    [
      create(:project, group: target_group),
      create(:project, group: subgroup)
    ]
  end

  let_it_be(:target_occurrences) do
    target_projects.map do |project|
      create(:sbom_occurrence, :with_vulnerabilities, project: project)
    end
  end

  before_all do
    # Records that should not be returned in the results
    create(:sbom_occurrence, project: outside_project)
    create(:sbom_occurrence, project: archived_project)
  end

  describe '#execute' do
    subject(:execute) { described_class.new(target_group, params: params).execute }

    it 'returns occurrences in target group hierarchy' do
      expected = target_occurrences.map do |occurrence|
        an_object_having_attributes(
          component_id: occurrence.component_id,
          component_version_id: occurrence.component_version_id,
          licenses: [],
          occurrence_count: 1,
          project_count: 1,
          vulnerability_count: 2
        )
      end

      expect(execute).to match_array(expected)
    end

    describe 'pagination' do
      let(:params) { { per_page: 1 } }

      it 'returns per_page + 1 items' do
        expect(execute.to_a.size).to eq(2)
      end

      context 'when per_page is over max page size' do
        let(:params) { { per_page: 2 } }
        let(:max) { 1 }

        before do
          stub_const("#{described_class}::MAX_PAGE_SIZE", max)
        end

        it 'returns max number of items + 1' do
          expect(execute.to_a.size).to eq(max + 1)
        end
      end
    end

    context 'when occurrences have licenses' do
      let_it_be(:occurrence_mit_apache_2) do
        create(:sbom_occurrence, :mit, :apache_2, :bundler, project: target_projects.first)
      end

      let_it_be(:occurrence_mpl) { create(:sbom_occurrence, :mpl_2, :nuget, project: target_projects.first) }
      let_it_be(:occurrence_apache_2) { create(:sbom_occurrence, :apache_2, :yarn, project: target_projects.first) }

      it 'returns the first license' do
        expect(execute).to match_array([
          an_object_having_attributes(
            component_id: occurrence_mit_apache_2.component_id,
            component_version_id: occurrence_mit_apache_2.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/MIT.html", "name" => "MIT License",
                         "spdx_identifier" => "MIT" }]),
          an_object_having_attributes(
            component_id: occurrence_mpl.component_id,
            component_version_id: occurrence_mpl.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/MPL-2.0.html",
                         "name" => "Mozilla Public License 2.0", "spdx_identifier" => "MPL-2.0" }]),
          an_object_having_attributes(
            component_id: occurrence_apache_2.component_id,
            component_version_id: occurrence_apache_2.component_version_id,
            licenses: [{ "url" => "https://spdx.org/licenses/Apache-2.0.html",
                         "name" => "Apache 2.0 License", "spdx_identifier" => "Apache-2.0" }]),
          an_object_having_attributes(licenses: []),
          an_object_having_attributes(licenses: [])
        ])
      end
    end

    describe 'sorting' do
      let_it_be(:project) { target_projects.first }
      let_it_be(:occurrence_1) { occurrence(traits: [:npm], name: 'c', severity: 'low') }
      let_it_be(:occurrence_2) { occurrence(traits: [:mit, :apache_2, :bundler], name: 'b', severity: 'medium') }
      let_it_be(:occurrence_3) { occurrence(traits: [:mpl_2, :nuget], name: 'a', severity: 'high') }
      let_it_be(:occurrence_4) { occurrence(traits: [:apache_2, :yarn], name: 'd', severity: 'critical') }

      before_all do
        Sbom::Occurrence.id_in(target_occurrences.map(&:id)).delete_all
      end

      def occurrence(name:, severity:, traits: [])
        params = { component: create(:sbom_component, name: name), highest_severity: severity, project: project }

        create(:sbom_occurrence, *traits, **params)
      end

      shared_examples 'can sort in both asc and desc order' do |sort_by|
        context 'in ascending order' do
          let(:params) { { sort_by: sort_by, sort: direction } }
          let(:direction) { :asc }

          it "returns occurrences in ascending order of #{sort_by}" do
            expect(execute.to_a).to eq(expected_asc)
          end
        end

        context 'in descending order' do
          let(:params) { { sort_by: sort_by, sort: direction } }
          let(:direction) { :desc }

          it "returns occurrences in descending order of #{sort_by}" do
            expect(execute.to_a).to eq(expected_desc)
          end
        end
      end

      context 'when sorting by component_name' do
        it_behaves_like 'can sort in both asc and desc order', :component_name do
          let_it_be(:a_name) { occurrence_3 }
          let_it_be(:b_name) { occurrence_2 }
          let_it_be(:c_name) { occurrence_1 }
          let_it_be(:d_name) { occurrence_4 }

          let(:expected_asc) { [a_name, b_name, c_name, d_name] }
          let(:expected_desc) { [d_name, c_name, b_name, a_name] }
        end
      end

      context 'when sorting by highest_severity' do
        it_behaves_like 'can sort in both asc and desc order', :highest_severity do
          let_it_be(:low) { occurrence_1 }
          let_it_be(:medium) { occurrence_2 }
          let_it_be(:high) { occurrence_3 }
          let_it_be(:critical) { occurrence_4 }

          let(:expected_asc) { [low, medium, high, critical] }
          let(:expected_desc) { [critical, high, medium, low] }
        end
      end

      context 'when sorting by license id' do
        it_behaves_like 'can sort in both asc and desc order', :licenses do
          let_it_be(:blank_license_array) { occurrence_1 }
          let_it_be(:mit_apache) { occurrence_2 }
          let_it_be(:mpl) { occurrence_3 }
          let_it_be(:apache) { occurrence_4 }

          let(:expected_asc) { [apache, mit_apache, mpl, blank_license_array] }
          let(:expected_desc) { [blank_license_array, mpl, mit_apache, apache] }
        end
      end

      context 'when sorting by package manager' do
        it_behaves_like 'can sort in both asc and desc order', :package_manager do
          let_it_be(:npm) { occurrence_1 }
          let_it_be(:bundler) { occurrence_2 }
          let_it_be(:nuget) { occurrence_3 }
          let_it_be(:yarn) { occurrence_4 }

          let(:expected_asc) { [bundler, npm, nuget, yarn] }
          let(:expected_desc) { [yarn, nuget, npm, bundler] }
        end
      end
    end

    describe 'filtering by license' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:occurrence_apache_2) { create(:sbom_occurrence, :apache_2, project: target_projects.first) }
      let_it_be(:occurrence_mit) { create(:sbom_occurrence, :mit, project: target_projects.first) }
      let_it_be(:occurrence_mpl_2) { create(:sbom_occurrence, :mpl_2, project: target_projects.first) }
      let_it_be(:occurrence_apache_2_mpl_2) do
        create(:sbom_occurrence, :apache_2, :mpl_2, project: target_projects.first)
      end

      let_it_be(:unknown_1) { target_occurrences.first }
      let_it_be(:unknown_2) { target_occurrences.second }

      let(:params) { { licenses: input } }

      where(:input, :expected_occurrences) do
        %w[MIT MPL-2.0]     | [ref(:occurrence_mit), ref(:occurrence_mpl_2)]
        %w[MPL-2.0 unknown] | [ref(:occurrence_mpl_2), ref(:unknown_1), ref(:unknown_2)]
        %w[Apache-2.0]      | [ref(:occurrence_apache_2), ref(:occurrence_apache_2_mpl_2)]
        %w[unknown]         | [ref(:unknown_1), ref(:unknown_2)]
        []                  | [ref(:occurrence_apache_2), ref(:occurrence_mit), ref(:occurrence_mpl_2),
          ref(:occurrence_apache_2_mpl_2), ref(:unknown_1), ref(:unknown_2)]
      end

      with_them do
        it 'returns expected output for each input' do
          expected = expected_occurrences.map do |occurrence|
            an_object_having_attributes(
              component_id: occurrence.component_id,
              component_version_id: occurrence.component_version_id
            )
          end

          expect(execute.to_a).to match_array(expected)
        end
      end
    end
  end
end
