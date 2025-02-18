# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers
  using RSpec::Parameterized::TableSyntax

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  context 'when a single project provided' do
    it_behaves_like 'EE search service shared examples', ::Gitlab::ProjectSearchResults, ::Gitlab::Elastic::ProjectSearchResults do
      let_it_be(:scope) { create(:project) }

      let(:user) { scope.first_owner }
      let(:service) { described_class.new(user, scope, params) }
    end
  end

  describe '#elasticsearchable_scope' do
    let(:service) { described_class.new(user, project, scope: scope) }
    let(:scope) { 'blobs' }
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }

    it 'is set to project' do
      expect(service.elasticsearchable_scope).to eq(project)
    end

    context 'when the scope is users' do
      let(:scope) { 'users' }

      it 'is nil' do
        expect(service.elasticsearchable_scope).to be_nil
      end
    end
  end

  context 'when searching with Zoekt', :zoekt_settings_enabled do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:service) do
      described_class.new(
        (anonymous_user ? nil : user),
        project,
        search: 'foobar',
        scope: scope,
        basic_search: basic_search,
        advanced_search: advanced_search,
        source: source
      )
    end

    let(:search_code_with_zoekt) { true }
    let(:user_preference_enabled_zoekt) { true }
    let(:scope) { 'blobs' }
    let(:basic_search) { nil }
    let(:advanced_search) { nil }
    let(:zoekt_nodes) { create_list(:zoekt_node, 2) }
    let(:circuit_breaker) { instance_double(::Search::Zoekt::CircuitBreaker) }
    let(:circuit_breaker_operational) { true }
    let(:anonymous_user) { false }
    let(:source) { nil }

    before do
      allow(project).to receive(:search_code_with_zoekt?).and_return(search_code_with_zoekt)
      allow(user).to receive(:enabled_zoekt?).and_return(user_preference_enabled_zoekt)
      zoekt_ensure_namespace_indexed!(project.root_namespace)

      allow(service).to receive(:zoekt_nodes).and_return zoekt_nodes
      allow(::Search::Zoekt::CircuitBreaker).to receive(:new).with(*zoekt_nodes).and_return(circuit_breaker)
      allow(circuit_breaker).to receive(:operational?).and_return(circuit_breaker_operational)
    end

    it 'searches with Zoekt' do
      expect(service.use_zoekt?).to eq(true)
      expect(service.zoekt_searchable_scope).to eq(project)
      expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
    end

    context 'when advanced search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      it 'returns a Search::Zoekt::SearchResults' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when project does not have Zoekt enabled' do
      let(:search_code_with_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when project is archived' do
      it 'sets include_archived and include_filtered filters to true' do
        project.update!(archived: true)

        expect(service.use_zoekt?).to eq(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        result = service.execute
        expect(result).to be_kind_of(::Search::Zoekt::SearchResults)
        expect(result.filters[:include_archived]).to eq true
        expect(result.filters[:include_forked]).to eq true
      end
    end

    context 'when scope is not blobs' do
      let(:scope) { 'issues' }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when basic_search is requested' do
      let(:basic_search) { true }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when user set enabled_zoekt preference to false' do
      let(:user_preference_enabled_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service).not_to be_use_zoekt
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when circuit breaker is tripped' do
      let(:circuit_breaker_operational) { false }

      it 'does not search with Zoekt' do
        expect(service).not_to be_use_zoekt
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when anonymous user' do
      let(:anonymous_user) { true }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.zoekt_searchable_scope).to eq(project)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when search comes from API' do
      let(:source) { 'api' }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end

      context 'when zoekt_search_api is disabled' do
        before do
          stub_feature_flags(zoekt_search_api: false)
        end

        it 'does not search with Zoekt' do
          expect(service.use_zoekt?).to eq(false)
          expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
        end
      end
    end

    context 'when feature flag disable_zoekt_search_for_saas is enabled' do
      before do
        stub_feature_flags(disable_zoekt_search_for_saas: true)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end
  end

  context 'when a multiple projects provided' do
    it_behaves_like 'EE search service shared examples', ::Gitlab::ProjectSearchResults, ::Gitlab::Elastic::SearchResults do
      let_it_be(:group) { create(:group) }
      let_it_be(:scope) { create_list(:project, 3, namespace: group) }

      let(:user) { group.owner }
      let(:service) { described_class.new(user, scope, params) }
    end
  end

  context 'default branch support' do
    let_it_be(:scope) { create(:project) }

    let(:user) { scope.owner }
    let(:service) { described_class.new(user, scope, params) }

    describe '#use_default_branch?' do
      subject { service.use_default_branch? }

      context 'when repository_ref param is blank' do
        let(:params) { { search: '*' } }

        it { is_expected.to be_truthy }
      end

      context 'when repository_ref param provided' do
        let(:params) { { search: '*', scope: search_scope, repository_ref: 'test' } }

        where(:search_scope, :default_branch_given, :use_default_branch) do
          'issues'          | true   | true
          'issues'          | false  | true
          'merge_requests'  | true   | true
          'merge_requests'  | false  | true
          'notes'           | true   | true
          'notes'           | false  | true
          'milestones'      | true   | true
          'milestones'      | false  | true
          'blobs'           | true   | true
          'blobs'           | false  | false
          'wiki_blobs'      | true   | true
          'wiki_blobs'      | false  | false
          'commits'         | true   | true
          'commits'         | false  | false
        end

        with_them do
          before do
            allow(scope).to receive(:root_ref?).and_return(default_branch_given)
          end

          it { is_expected.to eq(use_default_branch) }
        end
      end
    end

    describe '#execute' do
      let(:params) { { search: '*' } }

      subject { service.execute }

      it 'returns Elastic results when searching non-default branch' do
        expect(service).to receive(:use_default_branch?).and_return(true)

        is_expected.to be_a(::Gitlab::Elastic::ProjectSearchResults)
      end

      it 'returns ordinary results when searching non-default branch' do
        expect(service).to receive(:use_default_branch?).and_return(false)

        is_expected.to be_a(::Gitlab::ProjectSearchResults)
      end
    end
  end

  context 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let_it_be(:group) { create(:group) }
    let_it_be(:public_project) { create(:project, :wiki_repo, :public) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let_it_be_with_reload(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:projects) { [project, project2] }
    let(:search_level) { project }

    context 'merge request' do
      let!(:merge_request) { create :merge_request, target_project: project, source_project: project }
      let!(:merge_request2) { create :merge_request, target_project: project2, source_project: project2, title: merge_request.title }
      let(:scope) { 'merge_requests' }
      let(:search) { merge_request.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_reporter_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility'
      end
    end

    context 'note' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on issues' do
        let!(:note) { create :note_on_issue, project: project }
        let!(:note2) { create :note_on_issue, project: project2, note: note.note }
        let!(:confidential_note) do
          note_author_and_assignee = user || project.creator
          issue = create(:issue, project: project, assignees: [note_author_and_assignee])
          create(:note, note: note.note, confidential: true, project: project, noteable: issue, author: note_author_and_assignee)
        end

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_notes_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on merge requests' do
        let!(:note) { create :note_on_merge_request, project: project }
        let!(:note2) { create :note_on_merge_request, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on commits' do
        let_it_be_with_reload(:project) { create(:project, :repository, namespace: group) }
        let_it_be_with_reload(:project2) { create(:project, :repository) }

        let!(:note) { create :note_on_commit, project: project }
        let!(:note2) { create :note_on_commit, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access_and_non_private_project_only
        end

        with_them do
          before do
            project.repository.index_commits_and_blobs
            project2.repository.index_commits_and_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on snippets' do
        let!(:note) { create :note_on_project_snippet, project: project }
        let!(:note2) { create :note_on_project_snippet, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end
    end

    context 'issue' do
      let!(:issue) { create :issue, project: project }
      let!(:issue2) { create :issue, project: project2, title: issue.title }
      let(:scope) { 'issues' }
      let(:search) { issue.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility'
      end
    end

    context 'wiki' do
      let_it_be_with_reload(:project) { create(:project, :wiki_repo) }

      let(:projects) { [project] }
      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      before do
        project.wiki.create_page('test.md', "# term")
        project.wiki.index_wiki_blobs
      end

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility'
      end

      it 'adds correct routing field in the elasticsearch request' do
        public_project.wiki.create_page('test.md', "# term")
        described_class.new(nil, public_project, search: search).execute.objects(scope)
        assert_routing_field("n_#{public_project.root_ancestor.id}")
      end
    end

    context 'milestone' do
      let!(:milestone) { create :milestone, project: project }

      where(:project_level, :issues_access_level, :merge_requests_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_milestone_access
      end

      with_them do
        it "respects visibility" do
          enable_admin_mode!(user) if admin_mode
          project.update!(
            visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s),
            issues_access_level: issues_access_level,
            merge_requests_access_level: merge_requests_access_level
          )

          ensure_elasticsearch_index!

          expect_search_results(user, 'milestones', expected_count: expected_count) do |user|
            described_class.new(user, project, search: milestone.title).execute
          end
        end
      end
    end
  end

  context 'sorting', :elastic_delete_by_query, :sidekiq_inline do
    context 'issues' do
      let(:scope) { 'issues' }
      let_it_be(:project) { create(:project, :public) }

      let!(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago) }

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, project, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, project, search: 'updated', sort: sort).execute }
      end
    end

    context 'merge requests' do
      let(:scope) { 'merge_requests' }
      let(:project) { create(:project, :public) }

      let!(:old_result) { create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1', title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1', title: 'updated very old', updated_at: 1.year.ago) }

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, project, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, project, search: 'updated', sort: sort).execute }
      end
    end
  end

  describe '#scope' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }

    subject(:service) { described_class.new(user, project, scope: scope) }

    context 'when scope passed is included in allowed_scopes' do
      let(:scope) { 'issues' }

      it 'returns that scope' do
        expect(service.scope).to eq('issues')
      end

      context 'when user does not have permission for the scope' do
        it 'chooses the first allowed scope which the user has permission for' do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_issue, project).and_return(false)
          allow(Ability).to receive(:allowed?).with(user, :read_code, project).and_return(false)

          expect(service.scope).to eq('merge_requests')
        end
      end
    end

    context 'when scope passed is not included in allowed_scopes' do
      let(:scope) { 'epics' }

      it 'chooses the first allowed scope which the user has permission for' do
        expect(service.scope).to eq('blobs')
      end
    end
  end
end
