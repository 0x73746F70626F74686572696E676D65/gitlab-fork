# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticDeleteProjectWorker, :elastic, feature_category: :global_search do
  subject(:worker) { described_class.new }

  # Create admin user and search globally to avoid dealing with permissions in
  # these tests
  let_it_be(:user) { create(:admin) }
  let_it_be(:helper) { Gitlab::Elastic::Helper.default }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:milestone) { create(:milestone, project: project) }
  let_it_be(:note) { create(:note, project: project) }
  let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
  let_it_be(:wiki) { project.wiki.create_page('index_page', 'Bla bla term') }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  # Extracted to a method as the `#elastic_search` methods using it below will
  # mutate the hash and mess up the following searches
  def search_options
    { options: { current_user: user, project_ids: :any } }
  end

  it 'deletes a project with all nested objects and clears the index_status', :sidekiq_inline do
    ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

    ensure_elasticsearch_index!

    expect(project.reload.index_status).not_to be_nil
    expect(Project.elastic_search('*', **search_options).records).to include(project)
    expect(Issue.elastic_search('*', **search_options).records).to include(issue)
    expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
    expect(Note.elastic_search('*', **search_options).records).to include(note)
    expect(MergeRequest.elastic_search('*', **search_options).records).to include(merge_request)
    expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).not_to be_empty
    expect(Repository.find_commits_by_message_with_elastic('*').count).to be > 0
    expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
      options: { project_id: project.id })).not_to be_empty

    worker.perform(project.id, project.es_id)

    ensure_elasticsearch_index!

    expect(Project.elastic_search('*', **search_options).total_count).to eq(0)
    expect(Issue.elastic_search('*', **search_options).total_count).to eq(0)
    expect(Milestone.elastic_search('*', **search_options).total_count).to eq(0)
    expect(Note.elastic_search('*', **search_options).total_count).to eq(0)
    expect(MergeRequest.elastic_search('*', **search_options).total_count).to eq(0)
    expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).to be_empty
    expect(Repository.find_commits_by_message_with_elastic('*').count).to eq(0)
    expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
      options: { project_id: project.id })).to be_empty

    # verify that entire main index is empty
    expect(helper.documents_count).to eq(0)

    expect(project.reload.index_status).to be_nil
  end

  it 'does not include indexes which do not exist' do
    allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    allow(helper).to receive(:index_exists?).and_return(false)

    expect(helper.client).to receive(:delete_by_query).with(a_hash_including(index: Project.index_name))
    expect(helper.client).to receive(:delete_by_query).with(a_hash_including(index: [helper.target_name]))
    expect(helper.client).to receive(:delete_by_query)
      .with(a_hash_including(index: ::Elastic::Latest::WikiConfig.index_name))

    worker.perform(1, 2)
  end

  it 'does not raise exception when project document not found' do
    expect { worker.perform(non_existing_record_id, "project_#{non_existing_record_id}") }.not_to raise_error
  end

  context 'when there is a version conflict in remove_project_document' do
    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper.client).to receive(:delete_by_query).and_raise(Elasticsearch::Transport::Transport::Errors::Conflict)
      allow(helper).to receive(:remove_wikis_from_the_standalone_index).and_return(nil)
    end

    it 'enqueues the worker to try again' do
      expect(described_class).to receive(:perform_in).with(1.minute, 1, 2, {}).twice

      expect { worker.perform(1, 2) }.not_to raise_error
    end
  end

  context 'when there is a version conflict in remove_children_documents' do
    before do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper.client).to receive(:delete_by_query).and_raise(Elasticsearch::Transport::Transport::Errors::Conflict)
      allow(helper).to receive(:remove_wikis_from_the_standalone_index).and_return(nil)

      ::Elastic::ProcessInitialBookkeepingService.track!(project)
      ::Elastic::ProcessInitialBookkeepingService.maintain_indexed_associations(project, [:issues])

      ensure_elasticsearch_index!
    end

    it 'enqueues the worker to try again' do
      expect(described_class).to receive(:perform_in).with(1.minute, project.id, project.es_id, {}).once

      expect { worker.perform(project.id, project.es_id) }.not_to raise_error
    end
  end

  context 'when namespace_routing_id is passed in options' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    it 'deletes the project' do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

      ensure_elasticsearch_index!

      expect(Project.elastic_search('*', **search_options).records).to include(project)

      worker.perform(project.id, project.es_id, namespace_routing_id: group.id)

      ensure_elasticsearch_index!

      expect(Project.elastic_search('*', **search_options).records).not_to include(project)
    end

    it 'does not raise exception when namespace document not found' do
      expect do
        worker.perform(project.id, project.es_id, namespace_routing_id: non_existing_record_id)
      end.not_to raise_error
    end
  end

  context 'when passed delete_project option of false', :sidekiq_inline do
    it 'deletes only the nested objects and clears the index_status' do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

      ensure_elasticsearch_index!

      expect(project.reload.index_status).not_to be_nil
      expect(Project.elastic_search('*', **search_options).records).to include(project)
      expect(Issue.elastic_search('*', **search_options).records).to include(issue)
      expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
      expect(Note.elastic_search('*', **search_options).records).to include(note)
      expect(MergeRequest.elastic_search('*', **search_options).records).to include(merge_request)
      expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).not_to be_empty
      expect(Repository.find_commits_by_message_with_elastic('*').count).to be > 0
      expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
        options: { project_id: project.id })).not_to be_empty

      worker.perform(project.id, project.es_id, delete_project: false)

      ensure_elasticsearch_index!

      expect(Project.elastic_search('*', **search_options).total_count).to eq(1)
      expect(Project.elastic_search('*', **search_options).records).to include(project)
      expect(Issue.elastic_search('*', **search_options).total_count).to eq(0)
      expect(Milestone.elastic_search('*', **search_options).total_count).to eq(0)
      expect(Note.elastic_search('*', **search_options).total_count).to eq(0)
      expect(MergeRequest.elastic_search('*', **search_options).total_count).to eq(0)
      expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).to be_empty
      expect(Repository.find_commits_by_message_with_elastic('*').count).to eq(0)
      expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
        options: { project_id: project.id })).to be_empty

      # verify that entire main index is empty
      expect(helper.documents_count).to eq(0)
      expect(helper.documents_count(index_name: Project.index_name)).to eq(1)

      expect(project.reload.index_status).to be_nil
    end
  end

  context 'when passed project_only option of true', :sidekiq_inline do
    it 'deletes only the project objects' do
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)

      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)

      ensure_elasticsearch_index!

      expect(project.reload.index_status).not_to be_nil
      expect(Project.elastic_search('*', **search_options).records).to include(project)
      expect(Issue.elastic_search('*', **search_options).records).to include(issue)
      expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
      expect(Note.elastic_search('*', **search_options).records).to include(note)
      expect(MergeRequest.elastic_search('*', **search_options).records).to include(merge_request)
      expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).not_to be_empty
      expect(Repository.find_commits_by_message_with_elastic('*').count).to be > 0
      expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
        options: { project_id: project.id })).not_to be_empty

      expect(helper.client).to receive(:delete).with(a_hash_including(index: Project.index_name)).once.and_call_original

      worker.perform(project.id, project.es_id, project_only: true)

      ensure_elasticsearch_index!

      expect(project.reload.index_status).not_to be_nil
      expect(Project.elastic_search('*', **search_options).total_count).to eq(0)
      expect(Issue.elastic_search('*', **search_options).records).to include(issue)
      expect(Milestone.elastic_search('*', **search_options).records).to include(milestone)
      expect(Note.elastic_search('*', **search_options).records).to include(note)
      expect(MergeRequest.elastic_search('*', **search_options).records).to include(merge_request)
      expect(Repository.elastic_search('*', **search_options, type: 'blob')[:blobs][:results].response).not_to be_empty
      expect(Repository.find_commits_by_message_with_elastic('*').count).to be > 0
      expect(ProjectWiki.__elasticsearch__.elastic_search_as_wiki_page('*',
        options: { project_id: project.id })).not_to be_empty

      expect(helper.documents_count(index_name: Project.index_name)).to eq(0)
    end
  end
end
