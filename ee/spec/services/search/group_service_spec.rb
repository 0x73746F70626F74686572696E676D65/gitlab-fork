# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::GroupSearchResults,
    ::Gitlab::Elastic::GroupSearchResults do
    let(:scope) { group }
    let(:service) { described_class.new(user, scope, params) }
  end

  describe 'group search', :elastic do
    let(:term) { "RandomName" }
    let(:nested_group) { create(:group, :nested) }

    # These projects shouldn't be found
    let(:outside_project) { create(:project, :public, name: "Outside #{term}") }
    let(:private_project) { create(:project, :private, namespace: nested_group, name: "Private #{term}") }
    let(:other_project)   { create(:project, :public, namespace: nested_group, name: 'OtherProject') }

    # These projects should be found
    let(:project1) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 1") }
    let(:project2) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 2") }
    let(:project3) { create(:project, :internal, namespace: nested_group.parent, name: "Outer #{term}") }

    let(:results) { described_class.new(user, search_group, search: term).execute }

    before do
      # Ensure these are present when the index is refreshed
      _ = [
        outside_project, private_project, other_project,
        project1, project2, project3
      ]

      ensure_elasticsearch_index!
    end

    context 'finding projects by name' do
      subject { results.objects('projects') }

      context 'in parent group' do
        let(:search_group) { nested_group.parent }

        it { is_expected.to match_array([project1, project2, project3]) }
      end

      context 'in subgroup' do
        let(:search_group) { nested_group }

        it { is_expected.to match_array([project1, project2]) }
      end
    end
  end

  describe '#elasticsearchable_scope' do
    let(:service) { described_class.new(user, group, scope: scope) }
    let(:scope) { 'blobs' }

    it 'is set to group' do
      expect(service.elasticsearchable_scope).to eq(group)
    end

    context 'when the scope is users' do
      let(:scope) { 'users' }

      it 'is nil' do
        expect(service.elasticsearchable_scope).to be_nil
      end
    end
  end

  context 'when searching with Zoekt', :zoekt_settings_enabled do
    let(:service) do
      described_class.new(user, group, search: 'foobar', scope: scope,
        basic_search: basic_search, page: page, source: source)
    end

    let(:source) { nil }
    let(:use_zoekt) { true }
    let(:scope) { 'blobs' }
    let(:basic_search) { nil }
    let(:page) { nil }
    let(:zoekt_nodes) { create_list(:zoekt_node, 2) }
    let(:circuit_breaker) { instance_double(::Search::Zoekt::CircuitBreaker) }
    let(:circuit_breaker_operational) { true }

    before do
      allow(group).to receive(:use_zoekt?).and_return(use_zoekt)
      allow(group).to receive(:search_code_with_zoekt?).and_return(use_zoekt)
      zoekt_ensure_namespace_indexed!(group)

      allow(service).to receive(:zoekt_nodes).and_return zoekt_nodes
      allow(::Search::Zoekt::CircuitBreaker).to receive(:new).with(*zoekt_nodes).and_return(circuit_breaker)
      allow(circuit_breaker).to receive(:operational?).and_return(circuit_breaker_operational)
    end

    it 'returns a Search::Zoekt::SearchResults' do
      expect(service.use_zoekt?).to eq(true)
      expect(service.zoekt_searchable_scope).to eq(group)
      expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
    end

    context 'when advanced search is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
      end

      it 'returns a Search::Zoekt::SearchResults' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.zoekt_searchable_scope).to eq(group)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when group does not have Zoekt enabled' do
      let(:use_zoekt) { false }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
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

    context 'when application setting zoekt_search_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
        expect(service.execute).not_to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting the first page' do
      let(:page) { 1 }

      it 'searches with Zoekt' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when requesting a page other than the first' do
      let(:page) { 2 }

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(true)
        expect(service.execute).to be_kind_of(::Search::Zoekt::SearchResults)
      end
    end

    context 'when zoekt_code_search licensed feature is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it 'does not search with Zoekt' do
        expect(service.use_zoekt?).to eq(false)
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

  context 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let_it_be_with_reload(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'merge request' do
      let!(:merge_request) { create :merge_request, target_project: project, source_project: project }
      let!(:merge_request2) do
        create :merge_request, target_project: project2, source_project: project2, title: merge_request.title
      end

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
      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      it 'adds correct routing field in the elasticsearch request' do
        described_class.new(nil, search_level, search: search).execute.objects(scope)
        assert_routing_field("n_#{search_level.root_ancestor.id}")
      end

      context 'for project wikis' do
        let_it_be_with_reload(:project) { create(:project, :wiki_repo, :in_group) }

        let(:group) { project.namespace }
        let(:project_wiki) { create(:project_wiki, project: project, user: user) }
        let(:projects) { [project] }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            project_wiki.create_page('test.md', "# term")
            project.wiki.index_wiki_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'for group wikis' do
        let_it_be_with_reload(:group) { create(:group, :public, :wiki_enabled) }
        let_it_be_with_reload(:sub_group) { create(:group, :public, :wiki_enabled, parent: group) }
        let(:user) { create_user_from_membership(group, membership) }
        let_it_be(:group_wiki) { create(:group_wiki, container: group) }
        let_it_be(:sub_group_wiki) { create(:group_wiki, container: sub_group) }

        where(:group_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            [group_wiki, sub_group_wiki].each do |wiki|
              wiki.create_page('test.md', "# term")
              wiki.index_wiki_blobs
            end
          end

          it 'respects visibility' do
            enable_admin_mode!(user) if admin_mode
            sub_group.update!(
              visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
              wiki_access_level: feature_access_level.to_s
            )
            group.update!(
              visibility_level: Gitlab::VisibilityLevel.level_value(group_level.to_s),
              wiki_access_level: feature_access_level.to_s
            )
            ensure_elasticsearch_index!

            expect_search_results(user, scope, expected_count: expected_count * 2) do |user|
              described_class.new(user, search_level, search: search).execute
            end
          end
        end
      end
    end

    context 'milestone' do
      let!(:milestone) { create :milestone, project: project }

      where(:project_level, :issues_access_level, :merge_requests_access_level, :membership, :admin_mode,
        :expected_count) do
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
            described_class.new(user, group, search: milestone.title).execute
          end
        end
      end
    end

    context 'project' do
      let_it_be_with_reload(:project) { create(:project, namespace: group) }

      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it "respects visibility" do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          ElasticCommitIndexerWorker.new.perform(project.id)
          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, group, search: project.name).execute
          end
        end
      end
    end
  end

  context 'sorting', :elastic do
    context 'issues' do
      let(:scope) { 'issues' }
      let_it_be(:project) { create(:project, :public, group: group) }

      let!(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago) }

      let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end

    context 'merge requests' do
      let(:scope) { 'merge_requests' }
      let!(:project) { create(:project, :public, group: group) }

      let!(:new_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let!(:old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old',
          created_at: 1.month.ago)
      end

      let!(:very_old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let!(:new_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1', title: 'updated recent',
          updated_at: 1.day.ago)
      end

      let!(:old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old',
          updated_at: 1.month.ago)
      end

      let!(:very_old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1',
          title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }
      end
    end

    context 'epics' do
      let(:scope) { 'epics' }
      let_it_be(:member) { create(:group_member, :owner, group: group, user: user) }

      let!(:old_result) { create(:epic, group: group, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:epic, group: group, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:epic, group: group, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:epic, group: group, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:epic, group: group, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:epic, group: group, title: 'updated very old', updated_at: 1.year.ago) }

      let(:results_created) { described_class.new(user, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(user, group, search: 'updated', sort: sort).execute }

      before do
        stub_licensed_features(epics: true)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted'
    end
  end

  describe '#allowed_scopes' do
    let_it_be(:group) { create(:group) }

    subject(:allowed_scopes) { described_class.new(user, group, {}).allowed_scopes }

    context 'for blobs scope' do
      context 'when elasticearch_search is disabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it { is_expected.not_to include('blobs') }
      end

      context 'when elasticsearch_search is enabled and zoekt is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: true)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)
        end

        it { is_expected.to include('blobs') }
      end

      context 'when elasticsearch_search is disabled and zoekt is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_search: false)
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(true)
          allow(::Search::Zoekt).to receive(:search?).with(group).and_return(true)
        end

        it { is_expected.to include('blobs') }

        context 'but the group does is not enabled for zoekt' do
          before do
            allow(::Search::Zoekt).to receive(:search?).with(group).and_return(false)
          end

          it { is_expected.not_to include('blobs') }
        end
      end
    end

    context 'for epics scope' do
      before do
        stub_licensed_features(epics: epics_available)
      end

      context 'epics available' do
        let(:epics_available) { true }

        it 'does include epics to allowed_scopes' do
          expect(allowed_scopes).to include('epics')
        end
      end

      context 'epics is not available' do
        let(:epics_available) { false }

        it 'does not include epics to allowed_scopes' do
          expect(allowed_scopes).not_to include('epics')
        end
      end
    end
  end
end
