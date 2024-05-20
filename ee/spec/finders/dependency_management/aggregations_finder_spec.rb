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
  end
end
