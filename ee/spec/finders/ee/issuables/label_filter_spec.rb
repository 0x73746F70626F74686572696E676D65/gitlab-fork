# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::LabelFilter, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe '#label_link_query' do
    shared_examples 'does not run a labels union query' do
      it 'does not run a union query' do
        labels_filter = described_class.new(project: context_project, group: context_group, params: {})

        expect(labels_filter).not_to receive(:multi_target_label_links_query)

        labels_filter.label_link_query(issuables)
      end
    end

    shared_examples 'runs a labels union query' do
      it 'does not run a union query' do
        labels_filter = described_class.new(project: context_project, group: context_group, params: {})

        expect(labels_filter).to receive(:multi_target_label_links_query)

        labels_filter.label_link_query(issuables)
      end
    end

    context 'when filtering issues by label ' do
      let(:issuables) { Issue.all }

      context 'when at project level' do
        let(:context_project) { project }
        let(:context_group) { nil }

        it_behaves_like 'does not run a labels union query'
      end

      context 'when at group level' do
        let(:context_project) { nil }
        let(:context_group) { group }

        it_behaves_like 'does not run a labels union query'
      end
    end

    context 'when filtering work items by label ' do
      let(:issuables) { WorkItem.all }

      context 'when at project level' do
        let(:context_project) { project }
        let(:context_group) { nil }

        it_behaves_like 'does not run a labels union query'
      end

      context 'when at group level' do
        let(:context_project) { nil }
        let(:context_group) { group }

        it_behaves_like 'runs a labels union query'
      end
    end

    context 'when filtering epics by label ' do
      let(:issuables) { Epic.all }

      context 'when at group level' do
        let(:context_project) { nil }
        let(:context_group) { group }

        it_behaves_like 'runs a labels union query'
      end
    end
  end
end
