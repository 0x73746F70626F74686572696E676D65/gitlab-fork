# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::GroupSearchResults, :elastic, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:filters) { {} }
  let(:query) { '*' }

  subject(:results) { described_class.new(user, query, group.projects.pluck_primary_key, group: group, filters: filters) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_licensed_features(epics: true, group_wikis: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  context 'for issues search', :sidekiq_inline do
    let_it_be(:project) { create(:project, :public, group: group, developers: user) }
    let_it_be(:closed_result) { create(:issue, :closed, project: project, title: 'foo closed') }
    let_it_be(:opened_result) { create(:issue, :opened, project: project, title: 'foo opened') }
    let_it_be(:confidential_result) { create(:issue, :confidential, project: project, title: 'foo confidential') }

    let(:query) { 'foo' }
    let(:scope) { 'issues' }

    before do
      stub_feature_flags(search_uses_match_queries: true)
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    context 'when advanced search query syntax is used' do
      let(:query) { 'foo -banner' }

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by confidential'
      include_examples 'search results filtered by labels'
      it_behaves_like 'namespace ancestry_filter for aggregations' do
        let(:query_name) { 'filters:namespace:ancestry_filter:descendants' }
      end
    end

    context 'when search_uses_match_queries flag is false' do
      before do
        stub_feature_flags(search_uses_match_queries: false)
      end

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by confidential'
      include_examples 'search results filtered by labels'
      it_behaves_like 'namespace ancestry_filter for aggregations' do
        let(:query_name) { 'filters:namespace:ancestry_filter:descendants' }
      end
    end

    include_examples 'search results filtered by state'
    include_examples 'search results filtered by confidential'
    include_examples 'search results filtered by labels'
    it_behaves_like 'namespace ancestry_filter for aggregations' do
      let(:query_name) { 'filters:namespace:ancestry_filter:descendants' }
    end
  end

  context 'merge_requests search', :sidekiq_inline do
    let!(:project) { create(:project, :public, group: group) }
    let_it_be(:unarchived_project) { create(:project, :public, group: group) }
    let_it_be(:archived_project) { create(:project, :public, :archived, group: group) }
    let!(:opened_result) { create(:merge_request, :opened, source_project: project, title: 'foo opened') }
    let!(:closed_result) { create(:merge_request, :closed, source_project: project, title: 'foo closed') }
    let!(:unarchived_result) { create(:merge_request, source_project: unarchived_project, title: 'foo unarchived') }
    let!(:archived_result) { create(:merge_request, source_project: archived_project, title: 'foo archived') }

    let(:query) { 'foo' }
    let(:scope) { 'merge_requests' }

    before do
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by state'
    include_examples 'search results filtered by archived'
  end

  context 'blobs', :sidekiq_inline do
    let(:scope) { 'blobs' }

    context 'filter by language' do
      let_it_be(:project) { create(:project, :public, :repository, group: group) }

      it_behaves_like 'search results filtered by language'
    end

    it_behaves_like 'namespace ancestry_filter for aggregations'

    context 'filter by archived' do
      before do
        unarchived_project.repository.index_commits_and_blobs
        archived_project.repository.index_commits_and_blobs

        ensure_elasticsearch_index!

        allow(Gitlab::Search::FoundBlob).to receive(:new).and_return(instance_double(Gitlab::Search::FoundBlob))

        allow(Gitlab::Search::FoundBlob).to receive(:new)
          .with(a_hash_including(project_id: unarchived_project.id, ref: unarchived_project.commit.id)).and_return(unarchived_result)

        allow(Gitlab::Search::FoundBlob).to receive(:new)
          .with(a_hash_including(project_id: archived_project.id, ref: archived_project.commit.id)).and_return(archived_result)
      end

      let_it_be(:unarchived_project) { create(:project, :public, :repository, group: group) }
      let_it_be(:archived_project) { create(:project, :archived, :repository, :public, group: group) }

      let(:unarchived_result) { instance_double(Gitlab::Search::FoundBlob, project: unarchived_project) }
      let(:archived_result) { instance_double(Gitlab::Search::FoundBlob, project: archived_project) }
      let(:query) { 'something went wrong' }

      include_examples 'search results filtered by archived', nil, nil
    end
  end

  context 'for commits', :sidekiq_inline do
    let_it_be(:owner) { create(:user) }
    let_it_be(:unarchived_project) { create(:project, :public, :repository, group: group, creator: owner) }
    let_it_be(:archived_project) { create(:project, :archived, :repository, :public, group: group, creator: owner) }

    let_it_be(:unarchived_result_object) do
      unarchived_project.repository.create_file(owner, 'test.rb', '# foo bar', message: 'foo bar', branch_name: 'master')
    end

    let_it_be(:archived_result_object) do
      archived_project.repository.create_file(owner, 'test.rb', '# foo', message: 'foo', branch_name: 'master')
    end

    let(:unarchived_result) { unarchived_project.commit }
    let(:archived_result) { archived_project.commit }
    let(:scope) { 'commits' }
    let(:query) { 'foo' }

    before do
      unarchived_project.repository.index_commits_and_blobs
      archived_project.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by archived', nil, nil
  end

  context 'for wiki_blobs', :sidekiq_inline do
    let_it_be_with_reload(:owner) { create(:user) }
    let_it_be_with_reload(:group_wiki) { create(:group_wiki, group: group) }
    let_it_be_with_reload(:unarchived_project) { create(:project, :wiki_repo, :public, creator: owner) }
    let_it_be_with_reload(:archived_project) { create(:project, :archived, :wiki_repo, :public, creator: owner) }
    let(:scope) { 'wiki_blobs' }

    before do
      # Due to a bug https://gitlab.com/gitlab-org/gitlab/-/issues/423525
      # anonymous users can not search for group wikis in the public group
      # TODO: add_member code can be removed after fixing the bug.
      group.add_member(user, :owner)
      [unarchived_project, archived_project].each { |p| p.update!(group: group) }
      [unarchived_project.wiki, archived_project.wiki, group_wiki].each do |wiki|
        wiki.create_page('test.md', 'foo bar')
        wiki.index_wiki_blobs
      end
      ensure_elasticsearch_index!
    end

    context 'when include_archived is true' do
      let(:filters) do
        { include_archived: true }
      end

      it 'includes results from the archived project and group' do
        collection = results.objects(scope)
        expect(collection.size).to eq 3
        expect(collection.map(&:project)).to include(archived_project)
      end
    end

    context 'when migration reindex_wikis_to_fix_routing_and_backfill_archived is not finished' do
      before do
        set_elasticsearch_migration_to(:reindex_wikis_to_fix_routing_and_backfill_archived, including: false)
      end

      it 'includes results from the archived project' do
        collection = results.objects(scope)
        expect(collection.size).to eq 3
        expect(collection.map(&:project)).to include(archived_project)
      end
    end

    it 'excludes the wikis from the archived project' do
      collection = results.objects(scope)
      expect(collection.size).to eq 2
      expect(collection.map(&:project)).not_to include(archived_project)
    end
  end

  context 'for projects' do
    let!(:unarchived_result) { create(:project, :public, group: group) }
    let!(:archived_result) { create(:project, :archived, :public, group: group) }

    let(:scope) { 'projects' }

    it_behaves_like 'search results filtered by archived' do
      before do
        ensure_elasticsearch_index!
      end
    end

    context 'if the user is authorized to view the group' do
      it 'has a traversal_ids prefix filter' do
        group.add_owner(user)

        results.objects(scope)

        assert_named_queries('project:ancestry_filter:descendants', without: ['project:membership:id'])
      end
    end

    context 'if the user is not authorized to view the group' do
      it 'has a project id inclusion filter' do
        results.objects(scope)

        assert_named_queries('project:membership:id', without: ['project:ancestry_filter:descendants'])
      end
    end

    context 'if the advanced_search_project_traversal_ids_query flag is disabled' do
      before do
        stub_feature_flags(advanced_search_project_traversal_ids_query: false)
      end

      context 'if the user is authorized to view the group' do
        it 'has a project id inclusion filter' do
          group.add_owner(user)

          results.objects(scope)

          assert_named_queries('project:membership:id', without: ['project:ancestry_filter:descendants'])
        end
      end

      context 'if the user is not authorized to view the group' do
        it 'has a project id inclusion filter' do
          results.objects(scope)

          assert_named_queries('project:membership:id', without: ['project:ancestry_filter:descendants'])
        end
      end
    end
  end

  context 'epics search', :sidekiq_inline do
    let(:query) { 'foo' }
    let(:scope) { 'epics' }

    let_it_be(:public_parent_group) { create(:group, :public) }
    let_it_be(:group) { create(:group, :private, parent: public_parent_group) }
    let_it_be(:child_group) { create(:group, :private, parent: group) }
    let_it_be(:child_of_child_group) { create(:group, :private, parent: child_group) }
    let_it_be(:another_group) { create(:group, :private, parent: public_parent_group) }
    let!(:parent_group_epic) { create(:epic, group: public_parent_group, title: query) }
    let!(:group_epic) { create(:epic, group: group, title: query) }
    let!(:child_group_epic) { create(:epic, group: child_group, title: query) }
    let!(:confidential_child_group_epic) { create(:epic, :confidential, group: child_group, title: query) }
    let!(:confidential_child_of_child_epic) { create(:epic, :confidential, group: child_of_child_group, title: query) }
    let!(:another_group_epic) { create(:epic, group: another_group, title: query) }

    before do
      ensure_elasticsearch_index!
    end

    it 'returns no epics' do
      expect(results.objects('epics')).to be_empty
    end

    context 'when the user is a developer on the group' do
      before_all do
        group.add_developer(user)
      end

      it 'returns matching epics belonging to the group or its descendants, including confidential epics' do
        epics = results.objects('epics')

        expect(epics).to include(group_epic)
        expect(epics).to include(child_group_epic)
        expect(epics).to include(confidential_child_group_epic)

        expect(epics).not_to include(parent_group_epic)
        expect(epics).not_to include(another_group_epic)

        assert_named_queries(
          'epic:match:search_terms',
          'doc:is_a:epic',
          'namespace:ancestry_filter:descendants'
        )
      end

      context 'when searching from the child group' do
        it 'returns matching epics belonging to the child group, including confidential epics' do
          epics = described_class.new(user, query, [], group: child_group, filters: filters).objects('epics')

          expect(epics).to include(child_group_epic)
          expect(epics).to include(confidential_child_group_epic)

          expect(epics).not_to include(group_epic)
          expect(epics).not_to include(parent_group_epic)
          expect(epics).not_to include(another_group_epic)

          assert_named_queries(
            'epic:match:search_terms',
            'doc:is_a:epic',
            'namespace:ancestry_filter:descendants'
          )
        end
      end
    end

    context 'when the user is a guest of the child group and an owner of its child group' do
      before_all do
        child_group.add_guest(user)
      end

      it 'only returns non-confidential epics' do
        epics = described_class.new(user, query, [], group: child_group, filters: filters).objects('epics')

        expect(epics).to include(child_group_epic)
        expect(epics).not_to include(confidential_child_group_epic)

        assert_named_queries(
          'epic:match:search_terms',
          'doc:is_a:epic',
          'namespace:ancestry_filter:descendants',
          'confidential:false'
        )
      end

      context 'when the user is an owner of its child group' do
        before_all do
          child_of_child_group.add_owner(user)
        end

        it 'returns confidential epics from the child group' do
          epics = described_class.new(user, query, [], group: child_group, filters: filters).objects('epics')

          expect(epics).to include(child_group_epic)
          expect(epics).to include(confidential_child_of_child_epic)

          expect(epics).not_to include(confidential_child_group_epic)

          assert_named_queries(
            'epic:match:search_terms',
            'doc:is_a:epic',
            'namespace:ancestry_filter:descendants',
            'confidential:true',
            'groups:can:read_confidential_epics'
          )
        end
      end
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'epics'

    include_context 'with code examples' do
      before do
        code_examples.values.uniq.each do |description|
          sha = Digest::SHA256.hexdigest(description)
          create :epic, group: public_parent_group, title: sha, description: description
        end

        ensure_elasticsearch_index!
      end

      it 'finds all examples' do
        code_examples.each do |query, description|
          sha = Digest::SHA256.hexdigest(description)

          epics = described_class.new(user, query, [], group: public_parent_group, filters: filters).objects(scope)
          expect(epics.map(&:title)).to include(sha)
        end
      end
    end
  end

  describe 'users' do
    let(:query) { 'john' }
    let(:scope) { 'users' }
    let(:results) { described_class.new(user, query, group: group) }

    it 'returns an empty list' do
      create_list(:user, 3, name: "Sarah John")

      ensure_elasticsearch_index!

      users = results.objects('users')

      expect(users).to eq([])
      expect(results.users_count).to eq 0
    end

    context 'with group members' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:child_group) { create(:group, parent: group) }
      let_it_be(:child_of_parent_group) { create(:group, parent: parent_group) }
      let_it_be(:project_in_group) { create(:project, namespace: group) }
      let_it_be(:project_in_child_group) { create(:project, namespace: child_group) }
      let_it_be(:project_in_parent_group) { create(:project, namespace: parent_group) }
      let_it_be(:project_in_child_of_parent_group) { create(:project, namespace: child_of_parent_group) }

      it 'returns matching users who have access to the group' do
        users = create_list(:user, 8, name: "Sarah John")

        project_in_group.add_developer(users[0])
        project_in_child_group.add_developer(users[1])
        project_in_parent_group.add_developer(users[2])
        project_in_child_of_parent_group.add_developer(users[3])

        group.add_developer(users[4])
        parent_group.add_developer(users[5])
        child_group.add_developer(users[6])
        child_of_parent_group.add_developer(users[7])

        ensure_elasticsearch_index!

        expect(results.objects('users')).to contain_exactly(users[0], users[1], users[4], users[5], users[6])
        expect(results.users_count).to eq 5
      end
    end
  end

  describe '#notes' do
    let_it_be(:query) { 'foo' }
    let_it_be(:project) { create(:project, :public, namespace: group) }
    let_it_be(:archived_project) { create(:project, :public, :archived, namespace: group) }
    let_it_be(:note) { create(:note, project: project, note: query) }
    let_it_be(:note_on_archived_project) { create(:note, project: archived_project, note: query) }

    before do
      Elastic::ProcessBookkeepingService.track!(note, note_on_archived_project)
      ensure_elasticsearch_index!
    end

    context 'when migration backfill_archived_on_notes is not finished' do
      before do
        set_elasticsearch_migration_to(:backfill_archived_on_notes, including: false)
      end

      it 'includes the archived notes in the search results' do
        expect(subject.objects('notes')).to match_array([note, note_on_archived_project])
      end
    end

    context 'when filters contains include_archived as true' do
      let(:filters) do
        { include_archived: true }
      end

      it 'includes the archived notes in the search results' do
        expect(subject.objects('notes')).to match_array([note, note_on_archived_project])
      end
    end

    it 'does not includes the archived notes in the search results' do
      expect(subject.objects('notes')).to match_array([note])
    end
  end

  describe '#milestones' do
    let!(:unarchived_project) { create(:project, :public, group: group) }
    let!(:archived_project) { create(:project, :public, :archived, group: group) }
    let!(:unarchived_result) { create(:milestone, project: unarchived_project, title: 'foo unarchived') }
    let!(:archived_result) { create(:milestone, project: archived_project, title: 'foo archived') }
    let(:query) { 'foo' }
    let(:scope) { 'milestones' }

    before do
      set_elasticsearch_migration_to(:backfill_archived_on_milestones, including: true)
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by archived', nil, :backfill_archived_on_milestones
  end

  context 'query performance' do
    include_examples 'does not hit Elasticsearch twice for objects and counts',
      %w[projects notes blobs wiki_blobs commits issues merge_requests epics milestones users]
    include_examples 'does not load results for count only queries',
      %w[projects notes blobs wiki_blobs commits issues merge_requests epics milestones users]
  end

  describe '#scope_options' do
    context ':user' do
      it 'has not group_ids' do
        expect(subject.scope_options(:users)).not_to include :group_ids
      end
    end

    context ':wiki_blobs' do
      it 'has root_ancestor_ids' do
        expect(subject.scope_options(:wiki_blobs)).to include :root_ancestor_ids
      end
    end
  end
end
