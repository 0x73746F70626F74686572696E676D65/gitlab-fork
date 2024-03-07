# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuesFinder, feature_category: :team_planning do
  include_context 'Issues or WorkItems Finder context', :issue

  it_behaves_like 'issues or work items finder', :issue, '{Issues|WorkItems}Finder#execute context'

  context 'when filtering by group_id' do
    include_context '{Issues|WorkItems}Finder#execute context', :issue

    let(:params) { { group_id: group.id } }
    let(:scope) { 'all' }

    context 'when include_subgroup param not set' do
      it 'returns all group items' do
        expect(items).to contain_exactly(item1, item5)
      end

      context 'when projects outside the group are passed' do
        let(:params) { { group_id: group.id, projects: [project2.id] } }

        it 'returns no items' do
          expect(items).to be_empty
        end
      end

      context 'when projects of the group are passed' do
        let(:params) { { group_id: group.id, projects: [project1.id] } }

        it 'returns the item within the group and projects' do
          expect(items).to contain_exactly(item1, item5)
        end
      end

      context 'when projects of the group are passed as a subquery' do
        let(:params) { { group_id: group.id, projects: Project.id_in(project1.id) } }

        it 'returns the item within the group and projects' do
          expect(items).to contain_exactly(item1, item5)
        end
      end

      context 'when release_tag is passed as a parameter' do
        let(:params) { { group_id: group.id, release_tag: 'dne-release-tag' } }

        it 'ignores the release_tag parameter' do
          expect(items).to contain_exactly(item1, item5)
        end
      end
    end

    context 'when include_subgroup param is true' do
      before do
        params[:include_subgroups] = true
      end

      it 'returns all group and subgroup items' do
        expect(items).to contain_exactly(item1, item4, item5)
      end

      context 'when mixed projects are passed' do
        let(:params) { { group_id: group.id, projects: [project2.id, project3.id] } }

        it 'returns the item within the group and projects' do
          expect(items).to contain_exactly(item4)
        end
      end
    end
  end
end
