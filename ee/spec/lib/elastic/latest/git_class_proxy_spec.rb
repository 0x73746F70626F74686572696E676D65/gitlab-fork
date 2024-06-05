# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::GitClassProxy, :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, group: group) }

  let(:included_class) { Elastic::Latest::RepositoryClassProxy }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    ::Elastic::ProcessBookkeepingService.track!(project)
    project.repository.index_commits_and_blobs
    ensure_elasticsearch_index!
  end

  subject { included_class.new(project.repository.class) }

  describe '#elastic_search' do
    let_it_be(:user) { create(:user) }

    context 'when type is blob' do
      context 'when performing a global search' do
        let(:search_options) do
          {
            current_user: user,
            public_and_internal_projects: true,
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          subject.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob', 'blob:authorized:project', 'blob:match:search_terms')
        end
      end

      context 'when performing a group search' do
        let(:search_options) do
          {
            current_user: user,
            project_ids: [project.id],
            group_ids: [project.namespace.id],
            public_and_internal_projects: false,
            search_scope: "group",
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          subject.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob', 'blob:authorized:project', 'blob:match:search_terms')
        end

        context 'when user is authorized for the namespace' do
          it 'uses the correct elasticsearch query' do
            group.add_reporter(user)

            subject.elastic_search('*', type: 'blob', options: search_options)
            assert_named_queries('doc:is_a:blob', 'blob:match:search_terms', 'blob:authorized:reject_projects',
              'blob:authorized:namespace:ancestry_filter:descendants')
          end
        end

        context 'when the project is private' do
          let_it_be_with_reload(:project) { create(:project, :private, :repository, :in_group) }

          subject(:search_results) do
            included_class
              .new(project.repository.class)
              .elastic_search('Mailer.deliver', type: 'blob', options: search_options)
          end

          context 'when the user is not authorized' do
            it 'returns no search results' do
              expect(search_results[:blobs][:results]).to be_empty
            end
          end

          context 'when the user is a member' do
            where(:role, :expected_count) do
              [
                [:guest, 0],
                [:reporter, 1],
                [:developer, 1],
                [:maintainer, 1],
                [:owner, 1]
              ]
            end

            with_them do
              before do
                project.add_member(user, role)
              end

              it { expect(search_results[:blobs][:results].count).to eq(expected_count) }
            end
          end

          context 'with the `read_code` permission on a custom role' do
            let_it_be(:role) { create(:member_role, :guest, :read_code, namespace: project.group) }
            let_it_be(:member) { create(:group_member, :guest, member_role: role, user: user, source: project.group) }

            before do
              stub_licensed_features(custom_roles: true)
            end

            it 'returns matching search results' do
              expect(search_results[:blobs][:results].count).to eq(1)
              expect(search_results[:blobs][:results][0][:_source][:blob][:path]).to eq(
                'files/markdown/ruby-style-guide.md'
              )
            end

            context 'with saas', :saas do
              let_it_be(:subscription) do
                create(:gitlab_subscription, namespace: project.group, hosted_plan: create(:ultimate_plan))
              end

              before do
                stub_ee_application_setting(should_check_namespace_plan: true)
              end

              it 'returns matching search results' do
                expect(search_results[:blobs][:results].count).to eq(1)
                expect(search_results[:blobs][:results][0][:_source][:blob][:path]).to eq(
                  'files/markdown/ruby-style-guide.md'
                )
              end

              it 'avoids N+1 queries' do
                control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                  included_class
                    .new(project.repository.class)
                    .elastic_search('Mailer.deliver', type: 'blob', options: search_options)
                end

                projects = [
                  project,
                  create(:project, :private, :repository, group: create(:group, parent: project.group))
                ]

                expect do
                  included_class
                    .new(project.repository.class)
                    .elastic_search('Mailer.deliver', type: 'blob', options: search_options.merge(
                      project_ids: projects.map(&:id)
                    ))
                end.to issue_same_number_of_queries_as(control).or_fewer
              end
            end
          end
        end
      end

      context 'when performing a project search' do
        let(:search_options) do
          {
            current_user: user,
            project_ids: [project.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil,
            repository_id: project.id
          }
        end

        it 'uses the correct elasticsearch query' do
          subject.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob', 'blob:authorized:project',
            'blob:match:search_terms', 'blob:related:repositories')
        end

        context 'with the `read_code` permission on a custom role' do
          let_it_be(:project) { create(:project, :private, :repository, :in_group) }
          let_it_be(:role) { create(:member_role, :guest, :read_code, namespace: project.group) }
          let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, source: project) }

          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'returns matching search results' do
            search_results = subject.elastic_search('Mailer.deliver', type: 'blob', options: search_options)

            expect(search_results[:blobs][:results].count).to eq(1)
            expect(search_results[:blobs][:results][0][:_source][:blob][:path]).to eq(
              'files/markdown/ruby-style-guide.md'
            )
          end
        end

        context 'when the user is not authorized' do
          let_it_be(:project) { create(:project, :private, :repository, :in_group) }

          it 'returns no search results' do
            search_results = subject.elastic_search('Mailer.deliver', type: 'blob', options: search_options)

            expect(search_results[:blobs][:results]).to be_empty
          end
        end
      end
    end

    context 'when type is commit' do
      context 'when performing a global search' do
        let(:search_options) do
          {
            current_user: user,
            public_and_internal_projects: true,
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          subject.elastic_search('*', type: 'commit', options: search_options)
          assert_named_queries('doc:is_a:commit', 'commit:authorized:project', 'commit:match:search_terms')
        end
      end

      context 'when performing a group search' do
        let(:search_options) do
          {
            current_user: user,
            project_ids: [project.id],
            group_ids: [project.namespace.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          subject.elastic_search('*', type: 'commit', options: search_options)
          assert_named_queries('doc:is_a:commit', 'commit:authorized:project', 'commit:match:search_terms')
        end

        context 'when user is authorized for the namespace' do
          it 'uses the correct elasticsearch query' do
            group.add_reporter(user)

            subject.elastic_search('*', type: 'commit', options: search_options)
            assert_named_queries('doc:is_a:commit', 'commit:authorized:project', 'commit:match:search_terms')
          end
        end

        context 'when performing a project search' do
          let(:search_options) do
            {
              current_user: user,
              project_ids: [project.id],
              public_and_internal_projects: false,
              order_by: nil,
              sort: nil,
              repository_id: project.id
            }
          end

          it 'uses the correct elasticsearch query' do
            subject.elastic_search('*', type: 'commit', options: search_options)
            assert_named_queries('doc:is_a:commit', 'commit:authorized:project',
              'commit:match:search_terms', 'commit:related:repositories')
          end
        end

        context 'when requesting highlighting' do
          let(:search_options) do
            {
              current_user: user,
              project_ids: [project.id],
              public_and_internal_projects: false,
              order_by: nil,
              sort: nil,
              repository_id: project.id,
              highlight: true
            }
          end

          it 'returns highlight in the results' do
            results = subject.elastic_search('Add', type: 'commit', options: search_options)
            expect(results[:commits][:results].results.first.keys).to include('highlight')
          end
        end
      end
    end
  end

  describe '#elastic_search_as_found_blob', :aggregate_failures do
    it 'returns FoundBlob' do
      results = subject.elastic_search_as_found_blob('def popen')

      expect(results).not_to be_empty
      expect(results).to all(be_a(Gitlab::Search::FoundBlob))

      result = results.first

      expect(result.ref).to eq('b83d6e391c22777fca1ed3012fce84f633d7fed0')
      expect(result.path).to eq('files/ruby/popen.rb')
      expect(result.startline).to eq(2)
      expect(result.data).to include('Popen')
      expect(result.project).to eq(project)
    end

    context 'with filters in the query' do
      let(:query) { 'def extension:rb path:files/ruby' }

      it 'returns matching results' do
        results = subject.elastic_search_as_found_blob(query)
        paths = results.map(&:path)

        expect(paths).to contain_exactly('files/ruby/regex.rb',
          'files/ruby/popen.rb',
          'files/ruby/version_info.rb')
      end

      context 'when part of the path is used ' do
        let(:query) { 'def extension:rb path:files' }

        it 'returns the same results as when the full path is used' do
          results = subject.elastic_search_as_found_blob(query)
          paths = results.map(&:path)

          expect(paths).to contain_exactly('files/ruby/regex.rb',
            'files/ruby/popen.rb',
            'files/ruby/version_info.rb')
        end

        context 'when the path query is in the middle of the file path' do
          let(:query) { 'def extension:rb path:ruby' }

          it 'returns the same results as when the full path is used' do
            results = subject.elastic_search_as_found_blob(query)
            paths = results.map(&:path)

            expect(paths).to contain_exactly('files/ruby/regex.rb',
              'files/ruby/popen.rb',
              'files/ruby/version_info.rb')
          end
        end
      end
    end
  end

  describe '#blob_aggregations' do
    let_it_be(:user) { create(:user) }

    let(:options) do
      {
        current_user: user,
        project_ids: [project.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
    end

    before do
      project.add_developer(user)
    end

    it 'returns aggregations' do
      result = subject.blob_aggregations('This guide details how contribute to GitLab', options)

      expect(result.first.name).to eq('language')
      expect(result.first.buckets.first[:key]).to eq('Markdown')
      expect(result.first.buckets.first[:count]).to eq(2)
    end

    it 'assert names queries for global blob search when migration is complete' do
      search_options = {
        current_user: user,
        public_and_internal_projects: true,
        order_by: nil,
        sort: nil
      }
      subject.blob_aggregations('*', search_options)
      assert_named_queries('doc:is_a:blob', 'blob:authorized:project',
        'blob:match:search_terms')
    end

    it 'assert names queries for group blob search' do
      group_search_options = {
        current_user: user,
        project_ids: [project.id],
        group_ids: [project.namespace.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
      subject.blob_aggregations('*', group_search_options)
      assert_named_queries('doc:is_a:blob', 'blob:authorized:reject_projects', 'blob:match:search_terms',
        'blob:authorized:namespace:ancestry_filter:descendants')
    end

    it 'assert names queries for project blob search' do
      project_search_options = {
        current_user: user,
        project_ids: [project.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
      subject.blob_aggregations('*', project_search_options)
      assert_named_queries('doc:is_a:blob', 'blob:authorized:project', 'blob:match:search_terms')
    end
  end

  it "names elasticsearch queries" do
    subject.elastic_search_as_found_blob('*')

    assert_named_queries('doc:is_a:blob', 'blob:match:search_terms')
  end

  context 'when backfilling migration is complete' do
    let_it_be(:user) { create(:user) }

    it 'does not use the traversal_id filter when project_ids are passed' do
      expect(Namespace).not_to receive(:find)
      subject.elastic_search_as_found_blob('*', options: { current_user: user, project_ids: [1, 2] })
    end

    it 'does not use the traversal_id filter when group_ids are not passed' do
      expect(Namespace).not_to receive(:find)
      subject.elastic_search_as_found_blob('*', options: { current_user: user })
    end

    it 'uses the traversal_id filter' do
      expect(Namespace).to receive(:find).once.and_call_original
      subject.elastic_search_as_found_blob('*', options: { current_user: user, group_ids: [1] })
    end
  end
end
