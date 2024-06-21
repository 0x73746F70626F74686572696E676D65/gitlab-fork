# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Filters, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:query_hash) { { query: { bool: { filter: [], must_not: [], must: [], should: [] } } } }

  shared_examples 'does not modify the query_hash' do
    it 'does not add the filter to query_hash' do
      expect(subject).to eq(query_hash)
    end
  end

  describe '#by_not_hidden' do
    subject(:by_not_hidden) { described_class.by_not_hidden(query_hash: query_hash, options: options) }

    context 'when options[:current_user] is empty' do
      let(:options) { {} }

      it 'adds the hidden filter to query_hash' do
        expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

        expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
        expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
      end
    end

    context 'when options[:current_user] is present' do
      let(:options) { { current_user: user } }

      context 'when user cannot read all resources' do
        it 'adds the hidden filter to query_hash' do
          expected_filter = [{ term: { hidden: { _name: 'filters:not_hidden', value: false } } }]

          expect(by_not_hidden.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_not_hidden.dig(:query, :bool, :must)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :must_not)).to be_empty
          expect(by_not_hidden.dig(:query, :bool, :should)).to be_empty
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
        expected_filter = [{ match: { state: { _name: 'filters:state', query: 'opened' } } }]

        expect(by_state.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_state.dig(:query, :bool, :must)).to be_empty
        expect(by_state.dig(:query, :bool, :must_not)).to be_empty
        expect(by_state.dig(:query, :bool, :should)).to be_empty
      end
    end
  end

  describe '#by_archived' do
    subject(:by_archived) { described_class.by_archived(query_hash: query_hash, options: options) }

    context 'when options[:include_archived] is empty or false' do
      let(:options) { { include_archived: false, search_level: 'group' } }

      it 'adds the archived filter to query_hash' do
        expected_filter = [
          { bool: { _name: 'filters:non_archived',
                    should: [
                      { bool: { filter: { term: { archived: { value: false } } } } },
                      { bool: { must_not: { exists: { field: 'archived' } } } }
                    ] } }
        ]

        expect(by_archived.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_archived.dig(:query, :bool, :must)).to be_empty
        expect(by_archived.dig(:query, :bool, :must_not)).to be_empty
        expect(by_archived.dig(:query, :bool, :should)).to be_empty
      end

      context 'when options[:search_level] is project' do
        let(:options) { { include_archived: false, search_level: 'project' } }

        it 'adds the archived filter to query_hash' do
          expected_filter = [
            { bool: { _name: 'filters:non_archived',
                      should: [
                        { bool: { filter: { term: { archived: { value: false } } } } },
                        { bool: { must_not: { exists: { field: 'archived' } } } }
                      ] } }
          ]

          expect(by_archived.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_archived.dig(:query, :bool, :must)).to be_empty
          expect(by_archived.dig(:query, :bool, :must_not)).to be_empty
          expect(by_archived.dig(:query, :bool, :should)).to be_empty
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
        expected_filter = [
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
        ]

        expect(by_label_ids.dig(:query, :bool, :filter)).to eq(expected_filter)
        expect(by_label_ids.dig(:query, :bool, :must)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :must_not)).to be_empty
        expect(by_label_ids.dig(:query, :bool, :should)).to be_empty
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
          expected_filter = [
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
          ]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expected_filter = [{ term: { confidential: { _name: 'filters:non_confidential', value: false } } }]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
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
          expected_filter = [{ term: { confidential: true } }]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user is authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id]) }

        it 'adds the requested confidential filter to the query hash' do
          expected_filter = [{ term: { confidential: true } }]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when user is not authorized for all projects which the query is scoped to' do
        let(:options) { base_options.merge(project_ids: [authorized_project.id, private_project.id]) }

        it 'adds the confidential and non-confidential filters to query_hash' do
          expected_filter = [
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
          ]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end

      context 'when options[:current_user] is empty' do
        let(:options) { { project_ids: [authorized_project.id, private_project.id] } }

        it 'adds the non-confidential filters to query_hash' do
          expected_filter = [{ term: { confidential: { _name: 'filters:non_confidential', value: false } } }]

          expect(by_confidentiality.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_confidentiality.dig(:query, :bool, :must)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :must_not)).to be_empty
          expect(by_confidentiality.dig(:query, :bool, :should)).to be_empty
        end
      end
    end
  end

  describe '#by_authorization' do
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:authorized_project) { create(:project, group: public_group, developers: [user]) }
    let_it_be(:private_project) { create(:project, :private, group: public_group) }
    let_it_be(:public_project) { create(:project, :public, group: public_group) }
    let(:options) { base_options }
    let(:public_and_internal_projects) { false }
    let(:project_ids) { [] }
    let(:group_ids) { [] }
    let(:features) { 'issues' }
    let(:no_join_project) { false }
    let(:authorization_use_traversal_ids) { true }
    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        features: features,
        public_and_internal_projects: public_and_internal_projects,
        no_join_project: no_join_project,
        authorization_use_traversal_ids: authorization_use_traversal_ids,
        project_id_field: :project_id
      }
    end

    subject(:by_authorization) do
      described_class.by_authorization(query_hash: query_hash, options: options)
    end

    # anonymous users
    context 'when current_user is nil and project_ids is passed empty array' do
      let(:project_ids) { [] }
      let(:user) { nil }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [{ terms: { _name: 'filters:project', project_id: [] } }]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [{ terms: { _name: 'filters:project', project_id: [] } }]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }
        let(:options) { base_options.merge(features: 'issues') }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { terms: { _name: 'filters:project:membership:id', id: [] } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [20, 10]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                        { term: { 'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 } } }
                      ] } }
                ] } } } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: { _name: 'filters:project:membership:id', project_id: [] } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [20, 10]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                        } }
                      ] } }
                ]
              } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  _name: 'filters:project',
                  should: [
                    { bool:
                      { filter: [
                        { terms: { _name: 'filters:project:membership:id', foo: [] } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [20, 10]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                          } }
                        ] } }
                  ]
                } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed :any' do
      let(:project_ids) { :any }

      before do
        allow(user).to receive(:can_read_all_resources?).and_return(true)
      end

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [{ bool: { filter: [
                  { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                  { terms: { _name: 'filters:project:issues:enabled_or_private', 'issues_access_level' => [20, 10] } }
                ] } }] } } } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [{ bool: { filter: [
                          { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                          { terms: {
                            _name: 'filters:project:issues:enabled_or_private',
                            'issues_access_level' => [20, 10]
                          } }
                        ] } }] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [{ bool: { filter: [
                            { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                            { terms: {
                              _name: 'filters:project:issues:enabled_or_private',
                              'issues_access_level' => [20, 10]
                            } }
                          ] } }] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool: { filter: [
                    { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [20, 10]
                    } }
                  ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                        { terms: {
                          _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                          'issues_access_level' => [20, 10]
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                        { terms: {
                          _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                          'issues_access_level' => [20, 10]
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { _name: 'filters:project',
                        should: [
                          { bool:
                            { filter: [
                              { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                              { terms: { _name: 'filters:project:issues:enabled_or_private',
                                         'issues_access_level' => [20, 10] } }
                            ] } },
                          { bool:
                            { _name: 'filters:project:visibility:10:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                                { terms: {
                                  _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [20, 10]
                                } }
                              ] } },
                          { bool:
                            { _name: 'filters:project:visibility:20:issues:access_level',
                              filter: [
                                { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                                { terms: {
                                  _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                  'issues_access_level' => [20, 10]
                                } }
                              ] } }
                        ] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: { _name: 'filters:project',
                          should: [
                            { bool:
                              { filter: [
                                { term: { visibility_level: { _name: 'filters:project:any', value: 0 } } },
                                { terms: { _name: 'filters:project:issues:enabled_or_private',
                                           'issues_access_level' => [20, 10] } }
                              ] } },
                            { bool:
                              { _name: 'filters:project:visibility:10:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:10:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [20, 10]
                                  } }
                                ] } },
                            { bool:
                              { _name: 'filters:project:visibility:20:issues:access_level',
                                filter: [
                                  { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                                  { terms: {
                                    _name: 'filters:project:visibility:20:issues:access_level:enabled_or_private',
                                    'issues_access_level' => [20, 10]
                                  } }
                                ] } }
                          ] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when project_ids is passed an array' do
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { terms: {
              _name: 'filters:project',
              project_id: contain_exactly(authorized_project.id, public_project.id)
            } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { terms: {
                _name: 'filters:project',
                project_id: contain_exactly(authorized_project.id, public_project.id)
              } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { terms: { _name: 'filters:project', foo: contain_exactly(authorized_project.id, public_project.id) } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { has_parent:
              { _name: 'filters:project:parent', parent_type: 'project',
                query: { bool: { should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        id: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [20, 10]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                        } }
                      ] } }
                ] } } } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [{ bool: {
              _name: 'filters:project',
              should: [
                { bool:
                  { filter: [
                    { terms: {
                      _name: 'filters:project:membership:id',
                      project_id: contain_exactly(authorized_project.id, public_project.id)
                    } },
                    { terms: {
                      _name: 'filters:project:issues:enabled_or_private',
                      'issues_access_level' => [20, 10]
                    } }
                  ] } },
                { bool:
                  { _name: 'filters:project:visibility:10:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                      } }
                    ] } },
                { bool:
                  { _name: 'filters:project:visibility:20:issues:access_level',
                    filter: [
                      { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                      { term: {
                        'issues_access_level' =>
                          { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                      } }
                    ] } }
              ]
            } }]

            expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'and project_id_field is provided in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [{ bool: {
                _name: 'filters:project',
                should: [
                  { bool:
                    { filter: [
                      { terms: {
                        _name: 'filters:project:membership:id',
                        foo: contain_exactly(authorized_project.id, public_project.id)
                      } },
                      { terms: {
                        _name: 'filters:project:issues:enabled_or_private',
                        'issues_access_level' => [20, 10]
                      } }
                    ] } },
                  { bool:
                    { _name: 'filters:project:visibility:10:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                        } }
                      ] } },
                  { bool:
                    { _name: 'filters:project:visibility:20:issues:access_level',
                      filter: [
                        { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                        { term: {
                          'issues_access_level' =>
                            { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                        } }
                      ] } }
                ]
              } }]

              expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end
    end

    context 'when group_ids is passed an array' do
      let(:group_ids) { [public_group.id] }
      let(:project_ids) { [authorized_project.id, private_project.id, public_project.id] }

      context 'when public_and_internal_projects is false' do
        let(:public_and_internal_projects) { false }

        it 'returns the expected query' do
          expected_filter = [
            { bool: { should: [
              { prefix: { traversal_ids:
                { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
            ] } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when traversal_ids_prefix is set in options' do
          let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

          it 'returns the expected query' do
            expected_filter = [
              { bool: { should: [
                { prefix: { foo:
                  { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
              ] } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when authorization_use_traversal_ids is false in options' do
          let(:authorization_use_traversal_ids) { false }

          it 'returns the expected query' do
            expected_filter = [
              { terms: { _name: 'filters:project',
                         project_id: contain_exactly(authorized_project.id, public_project.id) } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                should: [
                  { prefix: { traversal_ids: {
                    _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-"
                  } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when authorization_use_traversal_ids is false in options' do
            let(:authorization_use_traversal_ids) { false }

            it 'returns the expected query' do
              expected_filter = [
                { terms: { _name: 'filters:project',
                           project_id: contain_exactly(authorized_project.id, public_project.id) } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to match(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when traversal_ids_prefix is set in options' do
            let(:options) { base_options.merge(traversal_ids_prefix: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  should: [
                    { prefix: { foo: {
                      _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-"
                    } } }
                  ]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  should: [
                    { prefix: { traversal_ids: {
                      _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-"
                    } } }
                  ]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when public_and_internal_projects is true' do
        let(:public_and_internal_projects) { true }

        it 'returns the expected query' do
          expected_filter = [
            { bool: { should: [
              { prefix:
                { traversal_ids:
                  { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
            ] } }
          ]
          expected_must_not = [
            { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
          ]

          expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
          expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
          expect(by_authorization.dig(:query, :bool, :must)).to be_empty
          expect(by_authorization.dig(:query, :bool, :should)).to be_empty
        end

        context 'when no_join_project is true' do
          let(:no_join_project) { true }

          it 'returns the expected query' do
            expected_filter = [
              { bool: {
                should: [
                  { prefix:
                    { traversal_ids:
                      { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                ]
              } }
            ]
            expected_must_not = [
              { terms: { _name: 'filters:reject_projects', project_id: [private_project.id] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when project_id_field is set in options' do
            let(:options) { base_options.merge(project_id_field: :foo) }

            it 'returns the expected query' do
              expected_filter = [
                { bool: {
                  should: [
                    { prefix:
                      { traversal_ids:
                        { _name: 'filters:namespace:ancestry_filter:descendants', value: "#{public_group.id}-" } } }
                  ]
                } }
              ]
              expected_must_not = [
                { terms: { _name: 'filters:reject_projects', foo: [private_project.id] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must_not)).to eq(expected_must_not)
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end
          end
        end
      end

      context 'when user is not authorized for the group_ids' do
        let_it_be(:internal_group) { create(:group, :internal) }
        let_it_be(:private_project) { create(:project, :private, group: internal_group) }
        let_it_be(:internal_project) { create(:project, :internal, group: internal_group) }

        let(:group_ids) { [internal_group.id] }
        let(:project_ids) { [private_project.id, internal_project.id] }

        context 'when public_and_internal_projects is false' do
          let(:public_and_internal_projects) { false }

          it 'returns the expected query' do
            expected_filter = [
              { terms: { _name: 'filters:project', project_id: [internal_project.id] } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { terms: { _name: 'filters:project', project_id: [internal_project.id] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:options) { base_options.merge(project_id_field: :foo) }

              it 'returns the expected query' do
                expected_filter = [
                  { terms: { _name: 'filters:project', foo: [internal_project.id] } }
                ]

                expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end

        context 'when public_and_internal_projects is true' do
          let(:public_and_internal_projects) { true }

          it 'returns the expected query' do
            expected_filter = [
              { has_parent:
                { _name: 'filters:project:parent', parent_type: 'project',
                  query: { bool: { should: [
                    { bool:
                      { filter: [
                        { terms: {
                          _name: 'filters:project:membership:id',
                          id: [internal_project.id]
                        } },
                        { terms: {
                          _name: 'filters:project:issues:enabled_or_private',
                          'issues_access_level' => [20, 10]
                        } }
                      ] } },
                    { bool:
                      { _name: 'filters:project:visibility:10:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                          } }
                        ] } },
                    { bool:
                      { _name: 'filters:project:visibility:20:issues:access_level',
                        filter: [
                          { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                          { term: {
                            'issues_access_level' =>
                              { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                          } }
                        ] } }
                  ] } } } }
            ]

            expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
            expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
            expect(by_authorization.dig(:query, :bool, :must)).to be_empty
            expect(by_authorization.dig(:query, :bool, :should)).to be_empty
          end

          context 'when no_join_project is true' do
            let(:no_join_project) { true }

            it 'returns the expected query' do
              expected_filter = [
                { bool:
                  { _name: 'filters:project',
                    should: [
                      { bool: { filter: [
                        { terms: { _name: 'filters:project:membership:id', project_id: [internal_project.id] } },
                        { terms: { _name: 'filters:project:issues:enabled_or_private',
                                   'issues_access_level' => [20, 10] } }
                      ] } },
                      { bool:
                        { _name: 'filters:project:visibility:10:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                            } }
                          ] } },
                      { bool:
                        { _name: 'filters:project:visibility:20:issues:access_level',
                          filter: [
                            { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                            { term: {
                              'issues_access_level' =>
                                { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                            } }
                          ] } }
                    ] } }
              ]

              expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
              expect(by_authorization.dig(:query, :bool, :must)).to be_empty
              expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
              expect(by_authorization.dig(:query, :bool, :should)).to be_empty
            end

            context 'when project_id_field is set in options' do
              let(:options) { base_options.merge(project_id_field: :foo) }

              it 'returns the expected query' do
                expected_filter = [
                  { bool:
                    { _name: 'filters:project',
                      should: [
                        { bool: { filter: [
                          { terms: { _name: 'filters:project:membership:id', foo: [internal_project.id] } },
                          { terms: { _name: 'filters:project:issues:enabled_or_private',
                                     'issues_access_level' => [20, 10] } }
                        ] } },
                        { bool:
                          { _name: 'filters:project:visibility:10:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:10', value: 10 } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:10:issues:access_level:enabled', value: 20 }
                              } }
                            ] } },
                        { bool:
                          { _name: 'filters:project:visibility:20:issues:access_level',
                            filter: [
                              { term: { visibility_level: { _name: 'filters:project:visibility:20', value: 20 } } },
                              { term: {
                                'issues_access_level' =>
                                  { _name: 'filters:project:visibility:20:issues:access_level:enabled', value: 20 }
                              } }
                            ] } }
                      ] } }
                ]

                expect(by_authorization.dig(:query, :bool, :filter)).to eq(expected_filter)
                expect(by_authorization.dig(:query, :bool, :must)).to be_empty
                expect(by_authorization.dig(:query, :bool, :must_not)).to be_empty
                expect(by_authorization.dig(:query, :bool, :should)).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
