# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Project, :elastic_delete_by_query, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  let(:schema_version) { 2402 }

  context 'when limited indexing is on' do
    let_it_be(:project) { create(:project, :empty_repo, name: 'main_project') }

    before do
      stub_ee_application_setting(elasticsearch_limit_indexing: true)
    end

    context 'when the project is not enabled specifically' do
      describe '#maintaining_elasticsearch?' do
        subject(:maintaining_elasticsearch) { project.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe '#use_elasticsearch?' do
        subject(:use_elasticsearch) { project.use_elasticsearch? }

        it { is_expected.to be(false) }
      end
    end

    context 'when a project is enabled specifically' do
      before do
        create(:elasticsearch_indexed_project, project: project)
      end

      describe '#maintaining_elasticsearch?' do
        subject(:maintaining_elasticsearch) { project.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe '#use_elasticsearch?' do
        subject(:use_elasticsearch) { project.use_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe 'indexing', :sidekiq_inline do
        it 'indexes all projects' do
          create(:project, :empty_repo, path: 'test_two', description: 'awesome project')
          ensure_elasticsearch_index!

          expect(described_class.elastic_search('main_project', options: { project_ids: :any }).total_count).to eq(1)
          expect(described_class.elastic_search('"test_two"', options: { project_ids: :any }).total_count).to eq(1)
        end
      end
    end

    context 'when a group is enabled', :sidekiq_inline do
      let_it_be(:group) { create(:group) }

      before_all do
        create(:elasticsearch_indexed_namespace, namespace: group)
      end

      describe '#maintaining_elasticsearch?' do
        let_it_be(:project_in_group) { create(:project, name: 'test1', group: group) }

        subject(:maintaining_elasticsearch) { project_in_group.maintaining_elasticsearch? }

        it { is_expected.to be(true) }
      end

      describe 'indexing' do
        it 'indexes all projects' do
          create(:project, name: 'group_test1', group: create(:group, parent: group))
          create(:project, name: 'group_test2', description: 'awesome project')
          create(:project, name: 'group_test3', group: group)
          ensure_elasticsearch_index!

          expect(described_class.elastic_search('group_test*', options: { project_ids: :any }).total_count).to eq(3)
          expect(described_class.elastic_search('"group_test3"', options: { project_ids: :any }).total_count).to eq(1)
          expect(described_class.elastic_search('"group_test2"', options: { project_ids: :any }).total_count).to eq(1)
        end
      end

      context 'default_operator' do
        RSpec.shared_examples 'use correct default_operator' do |operator|
          it 'uses correct operator', :sidekiq_inline do
            create(:project, name: 'project1', group: group, description: 'test foo')
            create(:project, name: 'project2', group: group, description: 'test')
            create(:project, name: 'project3', group: group, description: 'foo')

            ensure_elasticsearch_index!

            count_for_or = described_class.elastic_search('test | foo', options: { project_ids: :any }).total_count
            expect(count_for_or).to be > 0

            count_for_and = described_class.elastic_search('test + foo', options: { project_ids: :any }).total_count
            expect(count_for_and).to be > 0

            expect(count_for_or).not_to be equal(count_for_and)

            expected_count = case operator
                             when :or
                               count_for_or
                             when :and
                               count_for_and
                             else
                               raise ArgumentError, 'Invalid operator'
                             end

            expect(described_class.elastic_search('test foo',
              options: { project_ids: :any }).total_count).to eq(expected_count)
          end
        end

        context 'feature flag is enabled' do
          before do
            stub_feature_flags(elasticsearch_use_or_default_operator: true)
            stub_feature_flags(search_uses_match_queries: false)
          end

          include_examples 'use correct default_operator', :or
        end

        context 'feature flag is disabled' do
          before do
            stub_feature_flags(elasticsearch_use_or_default_operator: false)
            stub_feature_flags(search_uses_match_queries: false)
          end

          include_examples 'use correct default_operator', :and
        end
      end
    end
  end

  context 'when projects and snippets co-exist', issue: 'https://gitlab.com/gitlab-org/gitlab/issues/36340' do
    context 'when searching with a wildcard' do
      it 'only returns projects', :sidekiq_inline do
        create(:project)
        create(:snippet, :public)

        ensure_elasticsearch_index!
        response = described_class.elastic_search('*')

        expect(response.total_count).to eq(1)
        expect(response.results.first['_source']['type']).to eq(described_class.es_type)
      end
    end
  end

  it 'finds projects', :sidekiq_inline do
    project_ids = []

    project = create(:project, name: 'test1')
    project1 = create(:project, path: 'test2', description: 'awesome project')
    project2 = create(:project)
    create(:project, path: 'someone_elses_project')
    project_ids += [project.id, project1.id, project2.id]

    create(:project, :private, name: 'test3')

    ensure_elasticsearch_index!

    expect(described_class.elastic_search('"test1"', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('"test2"', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('"awesome"', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('test*', options: { project_ids: project_ids }).total_count).to eq(2)
    expect(described_class.elastic_search('test*', options: { project_ids: :any }).total_count).to eq(3)
    expect(described_class.elastic_search('"someone_elses_project"',
      options: { project_ids: project_ids }).total_count).to eq(0)
  end

  it 'finds partial matches in project names', :sidekiq_inline do
    project = create :project, name: 'tesla-model-s'
    project1 = create :project, name: 'tesla_model_s'
    project_ids = [project.id, project1.id]

    ensure_elasticsearch_index!

    expect(described_class.elastic_search('tesla', options: { project_ids: project_ids }).total_count).to eq(2)
  end

  it 'names elasticsearch queries' do
    described_class.elastic_search('*').total_count

    assert_named_queries('doc:is_a:project', 'project:match:search_terms')
  end

  describe '.as_indexed_json' do
    let_it_be(:project) { create(:project) }

    context 'when the migrate_projects_to_separate_index migration has not finished' do
      before do
        set_elasticsearch_migration_to(:migrate_projects_to_separate_index, including: false)
        ensure_elasticsearch_index!
      end

      it 'returns json with all needed elements' do
        expected_hash = project.attributes.extract!(
          'id',
          'name',
          'path',
          'description',
          'namespace_id',
          'created_at',
          'archived',
          'updated_at',
          'visibility_level',
          'last_activity_at'
        ).merge({
          'ci_catalog' => project.catalog_resource.present?,
          'join_field' => project.es_type,
          'type' => project.es_type,
          'schema_version' => schema_version,
          'traversal_ids' => project.elastic_namespace_ancestry,
          'name_with_namespace' => project.full_name,
          'path_with_namespace' => project.full_path
        })

        expected_hash.merge!(
          project.project_feature.attributes.extract!(
            'issues_access_level',
            'merge_requests_access_level',
            'snippets_access_level',
            'wiki_access_level',
            'repository_access_level'
          )
        )

        expect(project.__elasticsearch__.as_indexed_json).to eq(expected_hash)
      end
    end

    context 'when the migrate_projects_to_separate_index migration has finished' do
      before do
        set_elasticsearch_migration_to(:migrate_projects_to_separate_index, including: true)
        ensure_elasticsearch_index!
      end

      it 'returns json with all needed elements' do
        expected_hash = project.attributes.extract!(
          'id',
          'name',
          'path',
          'description',
          'namespace_id',
          'created_at',
          'archived',
          'updated_at',
          'visibility_level',
          'last_activity_at'
        ).merge({
          'ci_catalog' => project.catalog_resource.present?,
          'type' => project.es_type,
          'schema_version' => schema_version,
          'traversal_ids' => project.elastic_namespace_ancestry,
          'name_with_namespace' => project.full_name,
          'path_with_namespace' => project.full_path
        })

        expect(project.__elasticsearch__.as_indexed_json).to eq(expected_hash)
      end
    end

    context 'when the add_ci_catalog_to_project migration has not finished' do
      before do
        set_elasticsearch_migration_to(:add_ci_catalog_to_project, including: false)
      end

      it 'does not include the ci_catalog field' do
        expect(project.__elasticsearch__.as_indexed_json).not_to have_key('ci_catalog')
      end
    end
  end
end
