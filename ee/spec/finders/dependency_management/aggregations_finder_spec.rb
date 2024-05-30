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

      it 'uses per_page to determine page size' do
        expect(execute.to_a.size).to eq(1)
      end

      context 'when per_page is over max page size' do
        let(:params) { { per_page: 2 } }
        let(:max) { 1 }

        before do
          stub_const("#{described_class}::MAX_PAGE_SIZE", max)
        end

        it 'returns max number of items' do
          expect(execute.to_a.size).to eq(max)
        end
      end
    end

    context 'when sorting by component_name' do
      let_it_be(:project) { target_projects.first }
      let_it_be(:b_name) { create(:sbom_occurrence, component: component('b'), project: project) }
      let_it_be(:a_name) { create(:sbom_occurrence, component: component('a'), project: project) }
      let_it_be(:c_name) { create(:sbom_occurrence, component: component('c'), project: project) }

      let(:params) { { sort_by: 'component_name', sort: direction } }

      before_all do
        Sbom::Occurrence.id_in(target_occurrences.map(&:id)).delete_all
      end

      context 'in ascending order' do
        let(:direction) { :asc }

        it 'returns occurrences in ascending order of name' do
          expect(execute.to_a).to eq([a_name, b_name, c_name])
        end
      end

      context 'in descending order' do
        let(:direction) { :desc }

        it 'returns occurrences in descending order of name' do
          expect(execute.to_a).to eq([c_name, b_name, a_name])
        end
      end

      def component(name)
        create(:sbom_component, name: name)
      end
    end

    context 'when sorting by highest_severity' do
      let_it_be(:project) { target_projects.first }
      let_it_be(:low) { create(:sbom_occurrence, highest_severity: 'low', project: project) }
      let_it_be(:medium) { create(:sbom_occurrence, highest_severity: 'medium', project: project) }
      let_it_be(:high) { create(:sbom_occurrence, highest_severity: 'high', project: project) }
      let_it_be(:critical) { create(:sbom_occurrence, highest_severity: 'critical', project: project) }

      let(:params) { { sort_by: 'highest_severity', sort: direction } }

      before_all do
        Sbom::Occurrence.id_in(target_occurrences.map(&:id)).delete_all
      end

      context 'in ascending order' do
        let(:direction) { :asc }

        it 'returns occurrences in ascending order of severity' do
          expect(execute.to_a).to eq([low, medium, high, critical])
        end
      end

      context 'in descending order' do
        let(:direction) { :desc }

        it 'returns occurrences in descending order of severity' do
          expect(execute.to_a).to eq([critical, high, medium, low])
        end
      end
    end
  end
end
