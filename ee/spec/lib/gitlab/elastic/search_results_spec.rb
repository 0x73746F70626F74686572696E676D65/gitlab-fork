# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project_1.id] }

  describe '#highlight_map' do
    using RSpec::Parameterized::TableSyntax

    let(:proxy_response) do
      [{ _source: { id: 1 }, highlight: 'test <span class="gl-font-weight-bold">highlight</span>' }]
    end

    let(:results) { described_class.new(user, query, limit_project_ids) }
    let(:map) { { 1 => 'test <span class="gl-font-weight-bold">highlight</span>' } }

    where(:scope, :results_method, :expected) do
      'projects'       | :projects       | ref(:map)
      'milestones'     | :milestones     | ref(:map)
      'notes'          | :notes          | ref(:map)
      'issues'         | :issues         | ref(:map)
      'merge_requests' | :merge_requests | ref(:map)
      'blobs'          | nil             | nil
      'wiki_blobs'     | nil             | nil
      'commits'        | nil             | nil
      'epics'          | nil             | nil
      'users'          | nil             | nil
      'epics'          | nil             | nil
      'unknown'        | nil             | nil
    end

    with_them do
      it 'returns the expected highlight map' do
        expect(results).to receive(results_method).and_return(proxy_response) if results_method
        expect(results.highlight_map(scope)).to eq(expected)
      end
    end
  end

  describe '#formatted_count' do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query, limit_project_ids) }

    where(:scope, :count_method, :value, :expected) do
      'projects'       | :projects_count       | 0     | '0'
      'notes'          | :notes_count          | 100   | '100'
      'blobs'          | :blobs_count          | 1000  | '1,000'
      'wiki_blobs'     | :wiki_blobs_count     | 1111  | '1,111'
      'commits'        | :commits_count        | 9999  | '9,999'
      'issues'         | :issues_count         | 10000 | '10,000+'
      'merge_requests' | :merge_requests_count | 20000 | '10,000+'
      'milestones'     | :milestones_count     | nil   | '0'
      'epics'          | :epics_count          | 200   | '200'
      'users'          | :users_count          | 100   | '100'
      'epics'          | :epics_count          | 100   | '100'
      'unknown'        | nil                   | nil   | nil
    end

    with_them do
      it 'returns the expected formatted count limited and delimited' do
        expect(results).to receive(count_method).and_return(value) if count_method
        expect(results.formatted_count(scope)).to eq(expected)
      end
    end
  end

  describe '#aggregations', :elastic_delete_by_query do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query, limit_project_ids) }

    subject(:aggregations) { results.aggregations(scope) }

    where(:scope, :expected_aggregation_name, :feature_flag) do
      'projects'       | nil        | false
      'milestones'     | nil        | false
      'notes'          | nil        | false
      'issues'         | 'labels'   | false
      'merge_requests' | nil        | false
      'wiki_blobs'     | nil        | false
      'commits'        | nil        | false
      'users'          | nil        | false
      'epics'          | nil        | false
      'unknown'        | nil        | false
      'blobs'          | 'language' | false
    end

    with_them do
      context 'when feature flag is enabled for user' do
        let(:feature_enabled) { true }

        before do
          stub_feature_flags(feature_flag => user) if feature_flag
          results.objects(scope) # run search to populate aggregations
        end

        it_behaves_like 'loads expected aggregations'
      end

      context 'when feature flag is disabled for user' do
        let(:feature_enabled) { false }

        before do
          stub_feature_flags(feature_flag => false) if feature_flag
          results.objects(scope) # run search to populate aggregations
        end

        it_behaves_like 'loads expected aggregations'
      end
    end
  end

  shared_examples_for 'a paginated object' do |object_type|
    let(:results) { described_class.new(user, query, limit_project_ids) }

    it 'does not explode when given a page as a string' do
      expect { results.objects(object_type, page: "2") }.not_to raise_error
    end

    it 'paginates' do
      objects = results.objects(object_type, page: 2)
      expect(objects).to respond_to(:total_count, :limit, :offset)
      expect(objects.offset_value).to eq(20)
    end

    it 'uses the per_page value if passed' do
      objects = results.objects(object_type, page: 5, per_page: 1)
      expect(objects.offset_value).to eq(4)
    end
  end

  describe 'parse_search_result' do
    let_it_be(:project) { create(:project) }
    let(:content) { "foo\nbar\nbaz\n" }
    let(:path) { 'path/file.ext' }
    let(:source) do
      {
        'project_id' => project.id,
        'blob' => {
          'commit_sha' => 'sha',
          'content' => content,
          'path' => path
        }
      }
    end

    it 'returns an unhighlighted blob when no highlight data is present' do
      parsed = described_class.parse_search_result({ '_source' => source }, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        matched_lines_count: 0,
        startline: 1,
        highlight_line: nil,
        project: project,
        data: "foo\n"
      )
    end

    it 'parses the blob with highlighting' do
      result = {
        '_source' => source,
        'highlight' => {
          'blob.content' =>
            ["foo\n#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}" \
              "bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG}\nbaz\n"]
        }
      }

      parsed = described_class.parse_search_result(result, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        id: nil,
        path: 'path/file.ext',
        basename: 'path/file',
        ref: 'sha',
        matched_lines_count: 1,
        startline: 2,
        highlight_line: 2,
        project: project,
        data: "bar\n"
      )
    end

    it 'sets the correct matched_lines_count when the searched text found on the multiple lines' do
      result = {
        '_source' => source,
        'highlight' => {
          'blob.content' =>
            ["foo\n#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}bar" \
              "#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG}\nbaz\nfoo\n" \
              "#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}bar" \
              "#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG}\nbaz\n"]
        }
      }

      parsed = described_class.parse_search_result(result, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        id: nil,
        path: 'path/file.ext',
        basename: 'path/file',
        ref: 'sha',
        matched_lines_count: 2,
        startline: 2,
        highlight_line: 2,
        project: project,
        data: "bar\n"
      )
    end

    context 'when the highlighting finds the same terms multiple times' do
      let(:content) do
        <<~CONTENT
          bar
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
          bar
        CONTENT
      end

      it 'does not mistake a line that happens to include the same term that was highlighted on a later line' do
        highlighted_content = <<~CONTENT
          bar
          bar
          foo
          #{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG} # this is the highlighted bar
          baz
          boo
          bar
        CONTENT

        result = {
          '_source' => source,
          'highlight' => {
            'blob.content' => [highlighted_content]
          }
        }

        parsed = described_class.parse_search_result(result, project)

        expected_data = <<~EXPECTED_DATA
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
        EXPECTED_DATA

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(
          id: nil,
          path: 'path/file.ext',
          basename: 'path/file',
          ref: 'sha',
          startline: 2,
          highlight_line: 4,
          project: project,
          data: expected_data
        )
      end
    end

    context 'when file path in the blob contains potential backtracking regex attack pattern' do
      let(:path) { '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab.(a+)+$' }

      it 'still parses the basename from the path with reasonable amount of time' do
        Timeout.timeout(3.seconds) do
          parsed = described_class.parse_search_result({ '_source' => source }, project)

          expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
          expect(parsed).to have_attributes(
            basename: '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab'
          )
        end
      end
    end

    context 'when blob is a group level result' do
      let_it_be(:group) { create(:group) }
      let_it_be(:source) do
        {
          'type' => 'wiki_blob',
          'group_id' => group.id,
          'commit_sha' => 'sha',
          'content' => 'Test',
          'path' => 'home.md'
        }
      end

      it 'returns an instance of Gitlab::Search::FoundBlob with group_level_blob as true' do
        parsed = described_class.parse_search_result({ '_source' => source }, group)

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(group: group, project: nil, group_level_blob: true)
      end
    end
  end

  describe 'issues', :elastic_delete_by_query do
    let(:scope) { 'issues' }
    let!(:issue_1) do
      create(:issue, project: project_1, title: 'Hello world, here I am!',
        description: '20200623170000, see details in issue 287661', iid: 1)
    end

    let!(:issue_2) do
      create(:issue, project: project_1, title: 'Issue Two', description: 'Hello world, here I am!', iid: 2)
    end

    let!(:issue_3) { create(:issue, project: project_2, title: 'Issue Three', iid: 2) }

    before do
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'issues'

    it 'lists found issues' do
      results = described_class.new(user, query, limit_project_ids)
      issues = results.objects('issues')

      expect(issues).to contain_exactly(issue_1, issue_2)
      expect(results.issues_count).to eq 2
    end

    it 'returns empty list when issues are not found' do
      results = described_class.new(user, 'security', limit_project_ids)

      expect(results.objects('issues')).to be_empty
      expect(results.issues_count).to eq 0
    end

    it 'lists issue when search by a valid iid' do
      results = described_class.new(user, '#2', limit_project_ids, public_and_internal_projects: false)
      issues = results.objects('issues')

      expect(issues).to contain_exactly(issue_2)
      expect(results.issues_count).to eq 1
    end

    it 'can also find an issue by iid without the prefixed #' do
      results = described_class.new(user, '2', limit_project_ids, public_and_internal_projects: false)
      issues = results.objects('issues')

      expect(issues).to contain_exactly(issue_2)
      expect(results.issues_count).to eq 1
    end

    it 'finds the issue with an out of integer range number in its description without exception' do
      results = described_class.new(user, '20200623170000', limit_project_ids, public_and_internal_projects: false)
      issues = results.objects('issues')

      expect(issues).to contain_exactly(issue_1)
      expect(results.issues_count).to eq 1
    end

    it 'returns empty list when search by invalid iid' do
      results = described_class.new(user, '#222', limit_project_ids)

      expect(results.objects('issues')).to be_empty
      expect(results.issues_count).to eq 0
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'issues'

    it 'executes count only queries' do
      results = described_class.new(user, query, limit_project_ids)
      expect(results).to receive(:issues).with(count_only: true).and_call_original

      count = results.issues_count

      expect(count).to eq(2)
    end

    describe 'filtering' do
      let_it_be(:project) { create(:project, :public, developers: [user]) }
      let_it_be(:closed_result) { create(:issue, :closed, project: project, title: 'foo closed') }
      let_it_be(:opened_result) { create(:issue, :opened, project: project, title: 'foo opened') }
      let_it_be(:confidential_result) { create(:issue, :confidential, project: project, title: 'foo confidential') }

      let(:results) { described_class.new(user, 'foo', [project.id], filters: filters) }

      before do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by confidential'
      include_examples 'search results filtered by labels'

      context 'for projects' do
        let_it_be(:group) { create(:group) }
        let_it_be(:unarchived_result) { create(:project, :public, group: group) }
        let_it_be(:archived_result) { create(:project, :archived, :public, group: group) }

        let(:scope) { 'projects' }
        let(:results) { described_class.new(user, '*', [unarchived_result.id, archived_result.id], filters: filters) }

        it_behaves_like 'search results filtered by archived' do
          before do
            ::Elastic::ProcessBookkeepingService.track!(unarchived_result)
            ::Elastic::ProcessBookkeepingService.track!(archived_result)
            ensure_elasticsearch_index!
          end
        end
      end
    end

    describe 'ordering' do
      let_it_be(:project) { create(:project, :public) }

      let_it_be(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) { create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago) }

      let_it_be(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) do
        create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago)
      end

      let_it_be(:less_popular_result) { create(:issue, project: project, title: 'less popular', upvotes_count: 10) }
      let_it_be(:popular_result) { create(:issue, project: project, title: 'popular', upvotes_count: 100) }
      let_it_be(:non_popular_result) { create(:issue, project: project, title: 'non popular', upvotes_count: 1) }

      before do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(user, 'sorted', [project.id], sort: sort) }
        let(:results_updated) { described_class.new(user, 'updated', [project.id], sort: sort) }
      end

      include_examples 'search results sorted by popularity' do
        let(:results_popular) { described_class.new(user, 'popular', [project.id], sort: sort) }
      end
    end
  end

  describe 'notes', :elastic_delete_by_query do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue) { create(:issue, project: project, title: 'Hello') }
    let_it_be(:note_1) { create(:note, noteable: issue, project: project, note: 'foo bar') }
    let_it_be(:note_2) { create(:note_on_issue, noteable: issue, project: project, note: 'foo baz') }
    let_it_be(:note_3) { create(:note_on_issue, noteable: issue, project: project, note: 'bar bar') }
    let_it_be(:limit_project_ids) { [project.id] }

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'notes'

    it 'lists found notes' do
      results = described_class.new(user, 'foo', limit_project_ids)
      notes = results.objects('notes')

      expect(notes).to contain_exactly(note_1, note_2)
      expect(results.notes_count).to eq 2
    end

    context 'when comment has some code snippet' do
      before do
        code_examples.values.uniq.each do |note|
          sha = Digest::SHA256.hexdigest(note)
          create(:note_on_issue, noteable: issue, project: project, commit_id: sha, note: note)
        end
        ensure_elasticsearch_index!
      end

      include_context 'with code examples' do
        it 'finds all examples' do
          code_examples.each do |query, description|
            sha = Digest::SHA256.hexdigest(description)
            notes = described_class.new(user, query, limit_project_ids).objects('notes')
            expect(notes.map(&:commit_id)).to include(sha)
          end
        end
      end
    end

    it 'returns empty list when notes are not found' do
      results = described_class.new(user, 'security', limit_project_ids)

      expect(results.objects('notes')).to be_empty
      expect(results.notes_count).to eq 0
    end
  end

  describe 'confidential issues', :elastic_delete_by_query do
    let_it_be(:project_3) { create(:project, :public) }
    let_it_be(:project_4) { create(:project, :public) }
    let_it_be(:limit_project_ids) { [project_1.id, project_2.id, project_3.id] }
    let_it_be(:author) { create(:user) }
    let_it_be(:assignee) { create(:user) }
    let_it_be(:non_member) { create(:user) }
    let_it_be(:member) { create(:user) }
    let_it_be(:admin) { create(:admin) }
    let_it_be(:issue) { create(:issue, project: project_1, title: 'Issue 1', iid: 1) }
    let_it_be(:security_issue_1) do
      create(:issue, :confidential, project: project_1, title: 'Security issue 1', author: author, iid: 2)
    end

    let_it_be(:security_issue_2) do
      create(:issue, :confidential, title: 'Security issue 2',
        project: project_1, assignees: [assignee], iid: 3)
    end

    let_it_be(:security_issue_3) do
      create(:issue, :confidential, project: project_2, title: 'Security issue 3', author: author, iid: 1)
    end

    let_it_be(:security_issue_4) do
      create(:issue, :confidential, project: project_3,
        title: 'Security issue 4', assignees: [assignee], iid: 1)
    end

    let_it_be(:security_issue_5) do
      create(:issue, :confidential, project: project_4, title: 'Security issue 5', iid: 1)
    end

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1, project_2, project_3, project_4)
      ensure_elasticsearch_index!
    end

    context 'when searching by term' do
      let(:query) { 'issue' }

      it 'does not list confidential issues for guests' do
        results = described_class.new(nil, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for non project members' do
        results = described_class.new(non_member, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'lists confidential issues for author' do
        results = described_class.new(author, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_1, security_issue_3)
        expect(results.issues_count).to eq 3
      end

      it 'lists confidential issues for assignee' do
        results = described_class.new(assignee, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_2, security_issue_4)
        expect(results.issues_count).to eq 3
      end

      it 'lists confidential issues for project members' do
        project_1.add_developer(member)
        project_2.add_developer(member)

        results = described_class.new(member, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_1, security_issue_2, security_issue_3)
        expect(results.issues_count).to eq 4
      end

      context 'for admin users' do
        context 'when admin mode enabled', :enable_admin_mode do
          it 'lists all issues' do
            results = described_class.new(admin, query, limit_project_ids)
            issues = results.objects('issues')

            expect(issues).to contain_exactly(issue, security_issue_1,
              security_issue_2, security_issue_3, security_issue_4, security_issue_5)
            expect(results.issues_count).to eq 6
          end
        end

        context 'when admin mode disabled' do
          it 'does not list confidential issues' do
            results = described_class.new(admin, query, limit_project_ids)
            issues = results.objects('issues')

            expect(issues).to contain_exactly(issue)
            expect(results.issues_count).to eq 1
          end
        end
      end
    end

    context 'when searching by iid' do
      let(:query) { '#1' }

      it 'does not list confidential issues for guests' do
        results = described_class.new(nil, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'does not list confidential issues for non project members' do
        results = described_class.new(non_member, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue)
        expect(results.issues_count).to eq 1
      end

      it 'lists confidential issues for author' do
        results = described_class.new(author, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_3)
        expect(results.issues_count).to eq 2
      end

      it 'lists confidential issues for assignee' do
        results = described_class.new(assignee, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_4)
        expect(results.issues_count).to eq 2
      end

      it 'lists confidential issues for project members' do
        project_2.add_developer(member)
        project_3.add_developer(member)

        results = described_class.new(member, query, limit_project_ids)
        issues = results.objects('issues')

        expect(issues).to contain_exactly(issue, security_issue_3, security_issue_4)
        expect(results.issues_count).to eq 3
      end

      context 'for admin users' do
        context 'when admin mode enabled', :enable_admin_mode do
          it 'lists all issues' do
            results = described_class.new(admin, query, limit_project_ids)
            issues = results.objects('issues')

            expect(issues).to contain_exactly(issue, security_issue_3, security_issue_4, security_issue_5)
            expect(results.issues_count).to eq 4
          end
        end

        context 'when admin mode disabled' do
          it 'does not list confidential issues' do
            results = described_class.new(admin, query, limit_project_ids)
            issues = results.objects('issues')

            expect(issues).to contain_exactly(issue)
            expect(results.issues_count).to eq 1
          end
        end
      end
    end
  end

  describe 'merge requests', :elastic_delete_by_query do
    let(:scope) { 'merge_requests' }
    let_it_be(:merge_request_1) do
      create(:merge_request, source_project: project_1, target_project: project_1,
        title: 'Hello world, here I am!', description: '20200623170000, see details in issue 287661', iid: 1)
    end

    let_it_be(:merge_request_2) do
      create(:merge_request, :conflict, source_project: project_1, target_project: project_1,
        title: 'Merge Request Two', description: 'Hello world, here I am!', iid: 2)
    end

    let_it_be(:merge_request_3) do
      create(:merge_request, source_project: project_2, target_project: project_2, title: 'Merge Request Three', iid: 2)
    end

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project_1, project_2)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'merge_requests'

    it 'lists found merge requests' do
      results = described_class.new(user, query, limit_project_ids, public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_1, merge_request_2)
      expect(results.merge_requests_count).to eq 2
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'merge_requests'

    context 'when description has code snippets' do
      include_context 'with code examples' do
        before do
          code_examples.values.uniq.each.with_index do |code, idx|
            sha = Digest::SHA256.hexdigest(code)
            create :merge_request, target_branch: "feature#{idx}", source_project: project_1, target_project: project_1,
              title: sha, description: code
          end

          ensure_elasticsearch_index!
        end

        it 'finds all examples' do
          code_examples.each do |query, description|
            sha = Digest::SHA256.hexdigest(description)
            merge_requests = described_class.new(user, query, limit_project_ids).objects('merge_requests')
            expect(merge_requests.map(&:title)).to include(sha)
          end
        end
      end
    end

    it 'returns empty list when merge requests are not found' do
      results = described_class.new(user, 'security', limit_project_ids)

      expect(results.objects('merge_requests')).to be_empty
      expect(results.merge_requests_count).to eq 0
    end

    it 'lists merge request when search by a valid iid' do
      results = described_class.new(user, '!2', limit_project_ids, public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_2)
      expect(results.merge_requests_count).to eq 1
    end

    it 'can also find an issue by iid without the prefixed !' do
      results = described_class.new(user, '2', limit_project_ids, public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_2)
      expect(results.merge_requests_count).to eq 1
    end

    it 'finds the MR with an out of integer range number in its description without exception' do
      results = described_class.new(user, '20200623170000', limit_project_ids, public_and_internal_projects: false)
      merge_requests = results.objects('merge_requests')

      expect(merge_requests).to contain_exactly(merge_request_1)
      expect(results.merge_requests_count).to eq 1
    end

    it 'returns empty list when search by invalid iid' do
      results = described_class.new(user, '#222', limit_project_ids)

      expect(results.objects('merge_requests')).to be_empty
      expect(results.merge_requests_count).to eq 0
    end

    describe 'filtering' do
      let!(:project) { create(:project, :public) }
      let_it_be(:unarchived_project) { create(:project, :public) }
      let_it_be(:archived_project) { create(:project, :public, :archived) }
      let!(:opened_result) { create(:merge_request, :opened, source_project: project, title: 'foo opened') }
      let!(:closed_result) { create(:merge_request, :closed, source_project: project, title: 'foo closed') }
      let!(:unarchived_result) { create(:merge_request, source_project: unarchived_project, title: 'foo unarchived') }
      let!(:archived_result) { create(:merge_request, source_project: archived_project, title: 'foo archived') }
      let(:scope) { 'merge_requests' }
      let(:project_ids) { [project.id, unarchived_project.id, archived_project.id] }

      let(:results) { described_class.new(user, 'foo', project_ids, filters: filters) }

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by archived'
    end

    describe 'ordering' do
      let!(:project) { create(:project, :public) }

      let!(:old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old',
          created_at: 1.month.ago)
      end

      let!(:new_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent',
          created_at: 1.day.ago)
      end

      let!(:very_old_result) do
        create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old',
          created_at: 1.year.ago)
      end

      let!(:old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old',
          updated_at: 1.month.ago)
      end

      let!(:new_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1',
          title: 'updated recent', updated_at: 1.day.ago)
      end

      let!(:very_old_updated) do
        create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1',
          title: 'updated very old', updated_at: 1.year.ago)
      end

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(user, 'sorted', [project.id], sort: sort) }
        let(:results_updated) { described_class.new(user, 'updated', [project.id], sort: sort) }
      end
    end
  end

  describe 'milestones', :elastic_delete_by_query do
    let(:scope) { 'milestones' }

    describe 'filtering' do
      let!(:unarchived_project) { create(:project, :public) }
      let!(:archived_project) { create(:project, :public, :archived) }
      let!(:unarchived_result) { create(:milestone, project: unarchived_project, title: 'foo unarchived') }
      let!(:archived_result) { create(:milestone, project: archived_project, title: 'foo archived') }
      let(:project_ids) { [unarchived_project.id, archived_project.id] }
      let(:results) { described_class.new(user, 'foo', project_ids, filters: filters) }

      before do
        set_elasticsearch_migration_to(:backfill_archived_on_milestones, including: true)
        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by archived', nil, :backfill_archived_on_milestones
    end
  end

  describe 'users', :elastic_delete_by_query do
    let(:scope) { 'users' }
    let(:query) { 'john' }
    let(:results) { described_class.new(user, query, [], public_and_internal_projects: true) }
    let_it_be(:user_1) { create(:user, name: 'Sarah John') }
    let_it_be(:user_2) { create(:user, name: 'John Doe', state: :blocked) }
    let_it_be(:user_3) { create(:user, email: 'john@c.o') }

    before do
      ::Elastic::ProcessInitialBookkeepingService.track!(user_1, user_2, user_3)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'users'

    context 'when the user is not allowed to read users' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_users_list).and_return(false)
      end

      it 'returns an empty list' do
        expect(results.objects('users')).to be_empty
        expect(results.users_count).to eq 0
      end
    end

    context 'when the user is allowed to read users' do
      it 'lists found users' do
        users = results.objects('users')

        expect(users).to contain_exactly(user_1)
        expect(results.users_count).to eq 1
      end

      context 'when the calling user is an admin' do
        let_it_be(:user) { create(:user, admin: true) }

        it 'lists found users including blocked user and email match' do
          users = results.objects('users')

          expect(users).to contain_exactly(user_1, user_2, user_3)
          expect(results.users_count).to eq 3
        end
      end
    end
  end

  describe 'projects', :elastic_delete_by_query do
    it "returns items for project" do
      project = create :project, :repository, name: "term"
      project.add_developer(user)

      # Create issue
      create :issue, title: 'bla-bla term', project: project
      create :issue, description: 'bla-bla term', project: project
      create :issue, project: project
      # The issue I have no access to
      create :issue, title: 'bla-bla term'

      # Create Merge Request
      create :merge_request, title: 'bla-bla term', source_project: project
      create :merge_request, description: 'term in description', source_project: project, target_branch: "feature2"
      create :merge_request, source_project: project, target_branch: "feature3"
      # The merge request you have no access to
      create :merge_request, title: 'also with term'

      create :milestone, title: 'bla-bla term', project: project
      create :milestone, description: 'bla-bla term', project: project
      create :milestone, project: project
      # The Milestone you have no access to
      create :milestone, title: 'bla-bla term'

      ensure_elasticsearch_index!

      result = described_class.new(user, 'term', [project.id])

      expect(result.issues_count).to eq(2)
      expect(result.merge_requests_count).to eq(2)
      expect(result.milestones_count).to eq(2)
      expect(result.projects_count).to eq(1)
    end
  end

  describe 'blobs', :elastic_delete_by_query, :sidekiq_inline do
    before do
      project_1.repository.index_commits_and_blobs

      ensure_elasticsearch_index!
    end

    def search_for(term)
      described_class.new(user, term, [project_1.id]).objects('blobs').map(&:path)
    end

    it_behaves_like 'a paginated object', 'blobs'

    it 'finds blobs' do
      results = described_class.new(user, 'def', limit_project_ids)
      blobs = results.objects('blobs')

      expect(blobs.first.data).to include('def')
      expect(results.blobs_count).to eq 5
    end

    it 'finds blobs by prefix search' do
      results = described_class.new(user, 'defau*', limit_project_ids)
      blobs = results.objects('blobs')

      expect(blobs.first.data).to match(/default/i)
      expect(results.blobs_count).to eq 3
    end

    it 'finds blobs from public projects only' do
      project_2 = create :project, :repository, :private
      project_2.repository.index_commits_and_blobs
      project_2.add_reporter(user)
      ensure_elasticsearch_index!

      results = described_class.new(user, 'def', [project_1.id])
      expect(results.blobs_count).to eq 5
      result_project_ids = results.objects('blobs').map(&:project_id)
      expect(result_project_ids.uniq).to eq([project_1.id])

      results = described_class.new(user, 'def', [project_1.id, project_2.id])

      expect(results.blobs_count).to eq 10
    end

    it 'returns zero when blobs are not found' do
      results = described_class.new(user, 'asdfg', limit_project_ids)

      expect(results.blobs_count).to eq 0
    end

    describe 'searches CamelCased methods' do
      before_all do
        project_1.repository.create_file(
          user,
          'test.txt',
          ' function writeStringToFile(){} ',
          message: 'added test file',
          branch_name: 'master')
      end

      it 'find by first word' do
        expect(search_for('write')).to include('test.txt')
      end

      # Re-enable after fixing https://gitlab.com/gitlab-org/gitlab/-/issues/10693#note_349683299
      xit 'find by first two words' do
        expect(search_for('writeString')).to include('test.txt')
      end

      it 'find by last two words' do
        expect(search_for('ToFile')).to include('test.txt')
      end

      it 'find by exact match' do
        expect(search_for('writeStringToFile')).to include('test.txt')
      end

      it 'find by prefix search' do
        expect(search_for('writeStr*')).to include('test.txt')
      end
    end

    describe 'searches with special characters', :aggregate_failures do
      before do
        code_examples.values.uniq.each do |file_content|
          file_name = Digest::SHA256.hexdigest(file_content)
          project_1.repository.create_file(user, file_name, file_content, message: 'Some commit message',
            branch_name: 'master')
        end

        project_1.repository.index_commits_and_blobs
        ensure_elasticsearch_index!
      end

      include_context 'with code examples' do
        it 'finds all examples' do
          code_examples.each do |search_term, file_content|
            file_name = Digest::SHA256.hexdigest(file_content)

            expect(search_for(search_term)).to include(file_name), "failed to find #{search_term}"
          end
        end
      end
    end

    describe 'filtering' do
      let(:project) { project_1 }
      let(:results) { described_class.new(user, query, [project.id], filters: filters) }

      it_behaves_like 'search results filtered by language'
    end

    describe 'window size' do
      let(:filters) { {} }

      subject(:objects) do
        described_class.new(user, 'const_2', [project_1.id], filters: filters).objects('blobs')
      end

      before_all do
        project_1.repository.create_file(
          user,
          'test.rb',
          "# a comment

          SOME_CONSTANT = 123

          def const
            SOME_CONSTANT
          end

          def const_2
            SOME_CONSTANT * 2
          end

          def const_3
            SOME_CONSTANT * 3
          end",
          message: 'added test file',
          branch_name: 'master')
      end

      before do
        project_1.repository.index_commits_and_blobs

        ensure_elasticsearch_index!
      end

      it 'returns the line along with 2 lines before and after' do
        expect(objects.count).to eq(1)

        blob = objects.first

        expect(blob.highlight_line).to eq(9)
        expect(blob.data.lines.count).to eq(5)
        expect(blob.startline).to eq(7)
      end

      context 'if num_context_lines is 5' do
        let(:filters) { { num_context_lines: 5 } }

        it 'returns the line along with 5 lines before and after' do
          expect(objects.count).to eq(1)

          blob = objects.first

          expect(blob.highlight_line).to eq(9)
          expect(blob.data.lines.count).to eq(11)
          expect(blob.startline).to eq(4)
        end
      end
    end
  end

  describe 'wikis', :elastic_delete_by_query, :sidekiq_inline do
    let(:results) { described_class.new(user, 'term', limit_project_ids) }

    subject(:wiki_blobs) { results.objects('wiki_blobs') }

    before do
      if project_1.wiki_enabled?
        project_1.wiki.create_page('index_page', 'term')
        project_1.wiki.index_wiki_blobs
      end

      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'wiki_blobs'

    it 'finds wiki blobs' do
      blobs = results.objects('wiki_blobs')

      expect(blobs.first.data).to include('term')
      expect(results.wiki_blobs_count).to eq 1
    end

    it 'finds wiki blobs for guest' do
      project_1.add_guest(user)
      blobs = results.objects('wiki_blobs')

      expect(blobs.first.data).to include('term')
      expect(results.wiki_blobs_count).to eq 1
    end

    it 'finds wiki blobs from public projects only' do
      project_2 = create :project, :repository, :private, :wiki_repo
      project_2.wiki.create_page('index_page', 'term')
      project_2.wiki.index_wiki_blobs
      project_2.add_guest(user)
      ensure_elasticsearch_index!

      expect(results.wiki_blobs_count).to eq 1

      results = described_class.new(user, 'term', [project_1.id, project_2.id])
      expect(results.wiki_blobs_count).to eq 2
    end

    it 'returns zero when wiki blobs are not found' do
      results = described_class.new(user, 'asdfg', limit_project_ids)

      expect(results.wiki_blobs_count).to eq 0
    end

    context 'when wiki is disabled' do
      let(:project_1) { create(:project, :public, :repository, :wiki_disabled) }

      context 'when searching by member' do
        let(:limit_project_ids) { [project_1.id] }

        it { is_expected.to be_empty }
      end

      context 'when searching by non-member' do
        let(:limit_project_ids) { [] }

        it { is_expected.to be_empty }
      end
    end

    context 'when wiki is internal' do
      let_it_be(:project_1) { create(:project, :public, :repository, :wiki_private, :wiki_repo) }

      context 'when searching by member' do
        let_it_be(:limit_project_ids) { [project_1.id] }

        before_all do
          project_1.add_guest(user)
        end

        it { is_expected.not_to be_empty }
      end

      context 'when searching by non-member' do
        let(:limit_project_ids) { [] }

        it { is_expected.to be_empty }
      end
    end

    context 'for group wiki' do
      let_it_be(:sub_group) { create(:group, :nested) }
      let_it_be(:sub_group_wiki) { create(:group_wiki, group: sub_group) }
      let_it_be(:parent_group) { sub_group.parent }
      let_it_be(:parent_group_wiki) { create(:group_wiki, group: parent_group) }
      let_it_be(:group_project) { create(:project, :public, :in_group) }
      let_it_be(:group_project_wiki) { create(:project_wiki, project: group_project, user: user) }

      before do
        [parent_group_wiki, sub_group_wiki, group_project_wiki].each do |wiki|
          wiki.create_page('index_page', 'term')
          wiki.index_wiki_blobs
        end
        ElasticWikiIndexerWorker.new.perform(project_1.id, project_1.class.name, force: true)
        ensure_elasticsearch_index!
      end

      it 'includes all the wikis from groups, subgroups, projects and projects within the group' do
        expect(results.wiki_blobs_count).to eq 4
        wiki_containers = wiki_blobs.filter_map { |blob| blob.group_level_blob ? blob.group : blob.project }.uniq
        expect(wiki_containers).to contain_exactly(parent_group, sub_group, group_project, project_1)
      end
    end
  end

  describe 'commits', :elastic_delete_by_query, :sidekiq_inline do
    before do
      project_1.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'commits'

    it 'finds commits' do
      results = described_class.new(user, 'add', limit_project_ids)
      commits = results.objects('commits')

      expect(commits.first.message.downcase).to include("add")
      expect(results.commits_count).to eq 21
    end

    it 'finds commits from public projects only' do
      project_2 = create :project, :private, :repository
      project_2.repository.index_commits_and_blobs
      project_2.add_reporter(user)
      ensure_elasticsearch_index!

      results = described_class.new(user, 'add', [project_1.id])
      expect(results.commits_count).to eq 21

      results = described_class.new(user, 'add', [project_1.id, project_2.id])
      expect(results.commits_count).to eq 42
    end

    it 'returns zero when commits are not found' do
      results = described_class.new(user, 'asdfg', limit_project_ids)

      expect(results.commits_count).to eq 0
    end
  end

  describe 'visibility levels', :elastic_delete_by_query, :sidekiq_inline do
    let(:internal_project) { create(:project, :internal, :repository, :wiki_repo, description: "Internal project") }
    let(:private_project1) { create(:project, :private, :repository, :wiki_repo, description: "Private project") }
    let(:private_project2) do
      create(:project, :private, :repository, :wiki_repo, description: "Private project where I'm a member")
    end

    let(:public_project) { create(:project, :public, :repository, :wiki_repo, description: "Public project") }
    let(:limit_project_ids) { [private_project2.id] }

    before do
      private_project2.project_members.create!(user: user, access_level: ProjectMember::DEVELOPER)
    end

    describe 'issues' do
      shared_examples 'issues respect visibility' do
        it 'finds right set of issues' do
          issue_1 = create :issue, project: internal_project, title: "Internal project"
          create :issue, project: private_project1, title: "Private project"
          issue_3 = create :issue, project: private_project2, title: "Private project where I'm a member"
          issue_4 = create :issue, project: public_project, title: "Public project"

          ensure_elasticsearch_index!

          # Authenticated search
          results = described_class.new(user, 'project', limit_project_ids)
          issues = results.objects('issues')

          expect(issues).to include issue_1
          expect(issues).to include issue_3
          expect(issues).to include issue_4
          expect(results.issues_count).to eq 3

          # Unauthenticated search
          results = described_class.new(nil, 'project', [])
          issues = results.objects('issues')

          expect(issues).to include issue_4
          expect(results.issues_count).to eq 1
        end

        context 'when different issue descriptions', :aggregate_failures do
          let(:examples) do
            code_examples.merge(
              'screen' => 'Screenshots or screen recordings',
              'problem' => 'Problem to solve'
            )
          end

          include_context 'with code examples' do
            before do
              examples.values.uniq.each do |description|
                sha = Digest::SHA256.hexdigest(description)
                create :issue, project: private_project2, title: sha, description: description
              end

              ensure_elasticsearch_index!
            end

            it 'finds all examples' do
              examples.each do |search_term, description|
                sha = Digest::SHA256.hexdigest(description)

                results = described_class.new(user, search_term, limit_project_ids)
                issues = results.objects('issues')
                expect(issues.map(&:title)).to include(sha), "failed to find #{search_term}"
              end
            end
          end
        end
      end

      it_behaves_like 'issues respect visibility'

      context 'when search_uses_match_queries flag is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it_behaves_like 'issues respect visibility'
      end
    end

    describe 'milestones' do
      let!(:milestone_1) { create(:milestone, project: internal_project, title: "Internal project") }
      let!(:milestone_2) { create(:milestone, project: private_project1, title: "Private project") }
      let!(:milestone_3) do
        create(:milestone, project: private_project2, title: "Private project which user is member")
      end

      let!(:milestone_4) { create(:milestone, project: public_project, title: "Public project") }

      before do
        ensure_elasticsearch_index!
      end

      it_behaves_like 'a paginated object', 'milestones'

      context 'when project ids are present' do
        context 'when authenticated' do
          context 'when user and merge requests are disabled in a project' do
            it 'returns right set of milestones' do
              private_project2.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
              private_project2.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
              public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
              public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
              internal_project.project_feature.update!(issues_access_level: ProjectFeature::DISABLED)
              ensure_elasticsearch_index!

              projects = user.authorized_projects
              results = described_class.new(user, 'project', projects.pluck_primary_key)
              milestones = results.objects('milestones')

              expect(milestones).to match_array([milestone_1, milestone_3])
            end
          end

          context 'when user is admin' do
            context 'when admin mode enabled', :enable_admin_mode do
              it 'returns right set of milestones' do
                user.update!(admin: true)
                public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
                public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
                internal_project.project_feature.update!(issues_access_level: ProjectFeature::DISABLED)
                internal_project.project_feature.update!(merge_requests_access_level: ProjectFeature::DISABLED)
                ensure_elasticsearch_index!

                results = described_class.new(user, 'project', :any)
                milestones = results.objects('milestones')

                expect(milestones).to match_array([milestone_2, milestone_3, milestone_4])
              end
            end
          end

          context 'when user can read milestones' do
            it 'returns right set of milestones' do
              # Authenticated search
              projects = user.authorized_projects
              results = described_class.new(user, 'project', projects.pluck_primary_key)
              milestones = results.objects('milestones')

              expect(milestones).to match_array([milestone_1, milestone_3, milestone_4])
            end
          end
        end
      end

      context 'when not authenticated' do
        it 'returns right set of milestones' do
          results = described_class.new(nil, 'project', [])
          milestones = results.objects('milestones')

          expect(milestones).to include milestone_4
          expect(results.milestones_count).to eq 1
        end
      end

      context 'when project_ids is not present' do
        context 'when project_ids is :any' do
          it 'returns all milestones' do
            results = described_class.new(user, 'project', :any)

            milestones = results.objects('milestones')

            expect(results.milestones_count).to eq(4)

            expect(milestones).to include(milestone_1)
            expect(milestones).to include(milestone_2)
            expect(milestones).to include(milestone_3)
            expect(milestones).to include(milestone_4)
          end
        end

        context 'when authenticated' do
          it 'returns right set of milestones' do
            results = described_class.new(user, 'project', [])
            milestones = results.objects('milestones')

            expect(milestones).to include(milestone_1)
            expect(milestones).to include(milestone_4)
            expect(results.milestones_count).to eq(2)
          end
        end

        context 'when not authenticated' do
          it 'returns right set of milestones' do
            # Should not be returned because issues and merge requests feature are disabled
            other_public_project = create(:project, :public)
            create(:milestone, project: other_public_project, title: 'Public project milestone 1')
            other_public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
            other_public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
            # Should be returned because only issues is disabled
            other_public_project_1 = create(:project, :public)
            milestone_5 = create(:milestone, project: other_public_project_1, title: 'Public project milestone 2')
            other_public_project_1.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
            ensure_elasticsearch_index!

            results = described_class.new(nil, 'project', [])
            milestones = results.objects('milestones')

            expect(milestones).to match_array([milestone_4, milestone_5])
            expect(results.milestones_count).to eq(2)
          end
        end
      end
    end

    describe 'projects' do
      it_behaves_like 'a paginated object', 'projects'

      it 'finds right set of projects' do
        internal_project
        private_project1
        private_project2
        public_project

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project', limit_project_ids)
        milestones = results.objects('projects')

        expect(milestones).to include internal_project
        expect(milestones).to include private_project2
        expect(milestones).to include public_project
        expect(results.projects_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project', [])
        projects = results.objects('projects')

        expect(projects).to include public_project
        expect(results.projects_count).to eq 1
      end

      it 'returns 0 results for count only query' do
        public_project

        ensure_elasticsearch_index!

        results = described_class.new(user, '"noresults"')
        count = results.formatted_count('projects')
        expect(count).to eq('0')
      end
    end

    describe 'merge requests' do
      it 'finds right set of merge requests' do
        merge_request_1 = create :merge_request, target_project: internal_project, source_project: internal_project,
          title: "Internal project"
        create :merge_request, target_project: private_project1, source_project: private_project1,
          title: "Private project"
        merge_request_3 = create :merge_request, target_project: private_project2, source_project: private_project2,
          title: "Private project where I'm a member"
        merge_request_4 = create :merge_request, target_project: public_project, source_project: public_project,
          title: "Public project"

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project', limit_project_ids)
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_1
        expect(merge_requests).to include merge_request_3
        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project', [])
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 1
      end
    end

    describe 'wikis', :sidekiq_inline do
      before do
        [public_project, internal_project, private_project1, private_project2].each do |project|
          project.wiki.create_page('index_page', 'term')
          project.wiki.index_wiki_blobs
        end

        ensure_elasticsearch_index!
      end

      it 'finds the right set of wiki blobs' do
        # Authenticated search
        results = described_class.new(user, 'term', limit_project_ids)
        blobs = results.objects('wiki_blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.wiki_blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'term', [])
        blobs = results.objects('wiki_blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.wiki_blobs_count).to eq 1
      end
    end

    describe 'commits', :sidekiq_inline do
      it 'finds right set of commits' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file',
            'search test',
            message: 'search test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'search', limit_project_ids)
        commits = results.objects('commits')

        expect(commits.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.commits_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'search', [])
        commits = results.objects('commits')

        expect(commits.first.project).to eq public_project
        expect(results.commits_count).to eq 1
      end
    end

    describe 'blobs', :sidekiq_inline do
      it 'finds right set of blobs' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file',
            'tesla',
            message: 'search test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'tesla', limit_project_ids)
        blobs = results.objects('blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'tesla', [])
        blobs = results.objects('blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.blobs_count).to eq 1
      end
    end
  end

  describe 'query performance' do
    let(:results) { described_class.new(user, query, limit_project_ids) }

    include_examples 'does not hit Elasticsearch twice for objects and counts',
      %w[projects notes blobs wiki_blobs commits issues merge_requests milestones]
    include_examples 'does not load results for count only queries',
      %w[projects notes blobs wiki_blobs commits issues merge_requests milestones]
  end
end
