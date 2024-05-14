# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:query_hash) { { query: { bool: { filter: [] } } } }

  shared_examples 'does not modify the query_hash' do
    it 'does not add the filter to query_hash' do
      expect(subject).to eq({ query: { bool: { filter: [] } } })
    end
  end

  describe '#by_not_hidden' do
    subject(:by_not_hidden) { described_class.by_not_hidden(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is empty' do
      let(:options) { {} }

      it 'adds the hidden filter to query_hash' do
        expect(by_not_hidden).to eq(
          { query: { bool: { filter: [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }] } } }
        )
      end
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        it 'adds the hidden filter to query_hash' do
          expect(by_not_hidden).to eq(
            { query: { bool: { filter: [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }] } } }
          )
        end
      end

      context 'when user can read all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '#by_state' do
    subject(:by_state) { described_class.by_state(query_hash: query_hash, options: options) }

    context 'when options[:state] is empty' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] is all' do
      let(:options) { { state: 'all' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains an invalid search state' do
      let(:options) { { state: 'invalid' } }

      it_behaves_like 'does not modify the query_hash'
    end

    context 'when options[:state] contains a valid search state' do
      let(:options) { { state: 'opened' } }

      it 'adds the state filter to query_hash' do
        expect(by_state).to eq(
          { query: { bool: { filter: [{ match: { state: { _name: 'filters:state', query: 'opened' } } }] } } }
        )
      end
    end
  end

  describe '#by_archived' do
    subject(:by_archived) { described_class.by_archived(query_hash: query_hash, options: options) }

    context 'when options[:include_archived] is empty or false' do
      let(:options) { { include_archived: false, search_level: 'group' } }

      it 'adds the archived filter to query_hash' do
        expect(by_archived).to eq(
          { query: { bool: { filter: [
            { bool: { _name: 'filters:non_archived',
                      should: [
                        { bool: { filter: { term: { archived: { value: false } } } } },
                        { bool: { must_not: { exists: { field: 'archived' } } } }
                      ] } }
          ] } } }
        )
      end

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: false, search_level: 'project' } }

        it 'adds the archived filter to query_hash' do
          expect(by_archived).to eq(
            { query: { bool: { filter: [
              { bool: { _name: 'filters:non_archived',
                        should: [
                          { bool: { filter: { term: { archived: { value: false } } } } },
                          { bool: { must_not: { exists: { field: 'archived' } } } }
                        ] } }
            ] } } }
          )
        end
      end
    end

    context 'when options[:include_archived] is true' do
      let(:options) { { include_archived: true, search_level: 'group' } }

      it_behaves_like 'does not modify the query_hash'
      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: true, search_level: 'project' } }

        it_behaves_like 'does not modify the query_hash'
      end
    end
  end

  describe '#by_label_ids' do
    subject(:by_label_ids) { described_class.by_label_ids(query_hash: query_hash, options: options) }

    context 'when options[:labels] is provided' do
      let(:options) { { labels: [1] } }

      it 'adds the label_ids filter to query_hash' do
        expect(by_label_ids).to eq(
          { query: { bool: { filter: [
            {
              terms_set: {
                label_ids: {
                  _name: 'filters:label_ids',
                  terms: [1],
                  minimum_should_match_script: {
                    source: 'params.num_terms'
                  }
                }
              }
            }
          ] } } }
        )
      end

      context 'when options[:count_only] is true' do
        let(:options) { { labels: [1], count_only: true } }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when options[:aggregation] is true' do
        let(:options) { { labels: [1], aggregation: true } }

        it_behaves_like 'does not modify the query_hash'
      end
    end

    context 'when options[:labels] is not provided' do
      let(:options) { {} }

      it_behaves_like 'does not modify the query_hash'
    end
  end

  describe '#by_confidentiality' do
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let_it_be(:private_project) { create(:project, :private) }

    subject(:by_confidentiality) { described_class.by_confidentiality(query_hash: query_hash, options: options) }

    context 'when options[:confidential] is not passed or not true/false' do
      let(:base_options) { { current_user: user } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }

        it_behaves_like 'does not modify the query_hash'
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }

        it 'adds the confidential and non-confidential filters to query_hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [
              { bool: { should: [
                { term: { confidential: { _name: 'filters:non_confidential', value: false } } },
                { bool: { must: [
                  { term: { confidential: { _name: 'filters:confidential', value: true } } },
                  {
                    bool: {
                      should: [
                        { term: { author_id: { _name: 'filters:as_author', value: user.id } } },
                        { term: { assignee_id: { _name: 'filters:as_assignee', value: user.id } } },
                        { terms: { _name: 'filters:project:membership:id',
                                   project_id: [authorized_project.id] } }
                      ]
                    }
                  }
                ] } }
              ] } }
            ] } } }
          )
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [
              { term: { confidential: { _name: 'filters:non_confidential', value: false } } }
            ] } } }
          )
        end
      end
    end

    context 'when options[:confidential] is passed' do
      let(:base_options) { { current_user: user, confidential: true } }
      let(:options) { base_options }

      context 'when user.can_read_all_resources? is true' do
        before do
          allow(user).to receive(:can_read_all_resources?).and_return(true)
        end

        it 'adds the requested confidential filter to the query hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [{ term: { confidential: true } }] } } }
          )
        end
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }

        it 'adds the requested confidential filter to the query hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [{ term: { confidential: true } }] } } }
          )
        end
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }

        it 'adds the confidential and non-confidential filters to query_hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [
              { term: { confidential: true } },
              { bool: { should: [
                { term: { confidential: { _name: 'filters:non_confidential', value: false } } },
                { bool: { must: [
                  { term: { confidential: { _name: 'filters:confidential', value: true } } },
                  {
                    bool: {
                      should: [
                        { term: { author_id: { _name: 'filters:as_author', value: user.id } } },
                        { term: { assignee_id: { _name: 'filters:as_assignee', value: user.id } } },
                        { terms: { _name: 'filters:project:membership:id',
                                   project_id: [authorized_project.id] } }
                      ]
                    }
                  }
                ] } }
              ] } }
            ] } } }
          )
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expect(by_confidentiality).to eq(
            { query: { bool: { filter: [
              { term: { confidential: { _name: 'filters:non_confidential', value: false } } }
            ] } } }
          )
        end
      end
    end
  end
end
