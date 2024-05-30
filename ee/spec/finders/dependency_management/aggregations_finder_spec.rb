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

    describe 'sorting' do
      let_it_be(:project) { target_projects.first }
      let_it_be(:occurrence_1) { occurrence(packager: :npm, name: 'c', severity: 'low') }
      let_it_be(:occurrence_2) { occurrence(packager: :bundler, name: 'b', severity: 'medium') }
      let_it_be(:occurrence_3) { occurrence(packager: :nuget, name: 'a', severity: 'high') }
      let_it_be(:occurrence_4) { occurrence(packager: :yarn, name: 'd', severity: 'critical') }

      before_all do
        Sbom::Occurrence.id_in(target_occurrences.map(&:id)).delete_all
      end

      def occurrence(packager:, name:, severity:)
        component = create(:sbom_component, name: name)
        create(:sbom_occurrence, packager, component: component, highest_severity: severity, project: project)
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
        it_behaves_like 'can sort in both asc and desc order', 'component_name' do
          let_it_be(:a_name) { occurrence_3 }
          let_it_be(:b_name) { occurrence_2 }
          let_it_be(:c_name) { occurrence_1 }
          let_it_be(:d_name) { occurrence_4 }

          let(:expected_asc) { [a_name, b_name, c_name, d_name] }
          let(:expected_desc) { [d_name, c_name, b_name, a_name] }
        end
      end

      context 'when sorting by highest_severity' do
        it_behaves_like 'can sort in both asc and desc order', 'highest_severity' do
          let_it_be(:low) { occurrence_1 }
          let_it_be(:medium) { occurrence_2 }
          let_it_be(:high) { occurrence_3 }
          let_it_be(:critical) { occurrence_4 }

          let(:expected_asc) { [low, medium, high, critical] }
          let(:expected_desc) { [critical, high, medium, low] }
        end
      end

      context 'when sorting by package manager' do
        it_behaves_like 'can sort in both asc and desc order', 'package_manager' do
          let_it_be(:npm) { occurrence_1 }
          let_it_be(:bundler) { occurrence_2 }
          let_it_be(:nuget) { occurrence_3 }
          let_it_be(:yarn) { occurrence_4 }

          let(:expected_asc) { [bundler, npm, nuget, yarn] }
          let(:expected_desc) { [yarn, nuget, npm, bundler] }
        end
      end
    end
  end
end
