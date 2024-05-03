# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::WikiClassProxy, feature_category: :global_search do
  let_it_be(:project) { create(:project, :wiki_repo, :public, :wiki_enabled) }

  subject { described_class.new(Wiki, use_separate_indices: Wiki.use_separate_indices?) }

  describe 'assert query', :elastic do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    let(:options) do
      {
        current_user: nil,
        project_ids: [project.id],
        public_and_internal_projects: false,
        search_scope: 'project',
        repository_id: "wiki_#{project.id}"
      }
    end

    it 'returns the result from the separate index' do
      subject.elastic_search_as_wiki_page('*', options: options)
      assert_named_queries('wiki_blob:match:search_terms:separate_index')
    end
  end

  describe '#routing_options' do
    let(:n_routing) { 'n_1,n_2,n_3' }
    let(:ids) { [1, 2, 3] }
    let(:default_ops) { { root_ancestor_ids: ids, scope: 'wiki_blob' } }

    context 'when routing is disabled' do
      context 'and option routing_disabled is set' do
        it 'returns empty hash' do
          expect(subject.routing_options(default_ops.merge(routing_disabled: true))).to be_empty
        end
      end

      context 'and option public_and_internal_projects is set' do
        it 'returns empty hash' do
          expect(subject.routing_options(default_ops.merge(public_and_internal_projects: true))).to be_empty
        end
      end
    end

    context 'when ids count are more than 128' do
      it 'returns empty hash' do
        max_count = Elastic::Latest::Routing::ES_ROUTING_MAX_COUNT
        expect(subject.routing_options(default_ops.merge(root_ancestor_ids: 1.upto(max_count + 1).to_a))).to be_empty
      end
    end

    it 'returns routing hash' do
      expect(subject.routing_options(default_ops)).to eq({ routing: n_routing })
    end
  end
end
