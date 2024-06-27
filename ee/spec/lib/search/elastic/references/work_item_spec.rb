# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::WorkItem, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, :opened, labels: [label], namespace: group) }
  let_it_be(:user_work_item) { create(:work_item, :opened, labels: [label], namespace: create(:namespace)) }
  let_it_be(:project_work_item) { create(:work_item, :opened, labels: [label], project: project) }

  describe '#as_indexed_json' do
    subject { described_class.new(work_item.id, work_item.es_parent) }

    let(:result) { subject.as_indexed_json.with_indifferent_access }

    it 'serializes the project_namespace work_item as a hash' do
      result = described_class.new(project_work_item.id,
        project_work_item.es_parent).as_indexed_json.with_indifferent_access
      expect(result).to match(
        project_id: project_work_item.reload.project_id,
        id: project_work_item.id,
        iid: project_work_item.iid,
        created_at: project_work_item.created_at,
        updated_at: project_work_item.updated_at,
        title: project_work_item.title,
        description: project_work_item.description,
        state: project_work_item.state,
        upvotes: project_work_item.upvotes_count,
        hidden: project_work_item.hidden?,
        work_item_type_id: project_work_item.work_item_type_id,
        confidential: project_work_item.confidential,
        author_id: project_work_item.author_id,
        label_ids: [label.id.to_s],
        assignee_id: project_work_item.issue_assignee_user_ids,
        due_date: project_work_item.due_date,
        traversal_ids: project_work_item.namespace.elastic_namespace_ancestry,
        hashed_root_namespace_id: project_work_item.namespace.hashed_root_namespace_id,
        namespace_visibility_level: project_work_item.namespace.visibility_level,
        schema_version: described_class::SCHEMA_VERSION,
        archived: project.archived?,
        project_visibility_level: project.visibility_level,
        work_item_access_level: project.issues_access_level,
        type: 'work_item'
      )
    end

    it 'serializes the user_namespace work_item as a hash' do
      result = described_class.new(user_work_item.id, user_work_item.es_parent).as_indexed_json.with_indifferent_access
      expect(result).to match(
        project_id: user_work_item.reload.project_id,
        id: user_work_item.id,
        iid: user_work_item.iid,
        created_at: user_work_item.created_at,
        updated_at: user_work_item.updated_at,
        title: user_work_item.title,
        description: user_work_item.description,
        state: user_work_item.state,
        upvotes: user_work_item.upvotes_count,
        hidden: user_work_item.hidden?,
        work_item_type_id: user_work_item.work_item_type_id,
        confidential: user_work_item.confidential,
        author_id: user_work_item.author_id,
        label_ids: [label.id.to_s],
        assignee_id: user_work_item.issue_assignee_user_ids,
        due_date: user_work_item.due_date,
        traversal_ids: "#{user_work_item.namespace.id}-",
        hashed_root_namespace_id: user_work_item.namespace.hashed_root_namespace_id,
        namespace_visibility_level: user_work_item.namespace.visibility_level,
        schema_version: described_class::SCHEMA_VERSION,
        type: 'work_item'
      )
    end

    it 'serializes the object as a hash' do
      expect(result).to match(
        project_id: work_item.reload.project_id,
        id: work_item.id,
        iid: work_item.iid,
        namespace_id: group.id,
        created_at: work_item.created_at,
        updated_at: work_item.updated_at,
        title: work_item.title,
        description: work_item.description,
        state: work_item.state,
        upvotes: work_item.upvotes_count,
        hidden: work_item.hidden?,
        work_item_type_id: work_item.work_item_type_id,
        confidential: work_item.confidential,
        author_id: work_item.author_id,
        label_ids: [label.id.to_s],
        assignee_id: work_item.issue_assignee_user_ids,
        due_date: work_item.due_date,
        traversal_ids: "#{parent_group.id}-#{group.id}-",
        hashed_root_namespace_id: ::Search.hash_namespace_id(parent_group.id),
        namespace_visibility_level: group.visibility_level,
        schema_version: described_class::SCHEMA_VERSION,
        type: 'work_item'
      )
    end

    context 'when add_root_namespace_id_to_work_item migration is complete' do
      before do
        set_elasticsearch_migration_to :add_root_namespace_id_to_work_item, including: true
      end

      it 'serializes the project_namespace work_item as a hash' do
        result = described_class.new(project_work_item.id,
          project_work_item.es_parent).as_indexed_json.with_indifferent_access
        expect(result).to match(
          project_id: project_work_item.reload.project_id,
          id: project_work_item.id,
          iid: project_work_item.iid,
          root_namespace_id: project_work_item.namespace.root_ancestor.id,
          created_at: project_work_item.created_at,
          updated_at: project_work_item.updated_at,
          title: project_work_item.title,
          description: project_work_item.description,
          state: project_work_item.state,
          upvotes: project_work_item.upvotes_count,
          hidden: project_work_item.hidden?,
          work_item_type_id: project_work_item.work_item_type_id,
          confidential: project_work_item.confidential,
          author_id: project_work_item.author_id,
          label_ids: [label.id.to_s],
          assignee_id: project_work_item.issue_assignee_user_ids,
          due_date: project_work_item.due_date,
          traversal_ids: project_work_item.namespace.elastic_namespace_ancestry,
          hashed_root_namespace_id: project_work_item.namespace.hashed_root_namespace_id,
          namespace_visibility_level: project_work_item.namespace.visibility_level,
          schema_version: described_class::SCHEMA_VERSION,
          archived: project.archived?,
          project_visibility_level: project.visibility_level,
          work_item_access_level: project.issues_access_level,
          type: 'work_item'
        )
      end

      it 'serializes the object as a hash' do
        expect(result).to match(
          project_id: work_item.reload.project_id,
          id: work_item.id,
          iid: work_item.iid,
          namespace_id: group.id,
          root_namespace_id: parent_group.id,
          created_at: work_item.created_at,
          updated_at: work_item.updated_at,
          title: work_item.title,
          description: work_item.description,
          state: work_item.state,
          upvotes: work_item.upvotes_count,
          hidden: work_item.hidden?,
          work_item_type_id: work_item.work_item_type_id,
          confidential: work_item.confidential,
          author_id: work_item.author_id,
          label_ids: [label.id.to_s],
          assignee_id: work_item.issue_assignee_user_ids,
          due_date: work_item.due_date,
          traversal_ids: "#{parent_group.id}-#{group.id}-",
          hashed_root_namespace_id: ::Search.hash_namespace_id(parent_group.id),
          namespace_visibility_level: group.visibility_level,
          schema_version: described_class::SCHEMA_VERSION,
          type: 'work_item'
        )
      end

      it 'serializes the user_namespace work_item as a hash' do
        result = described_class.new(user_work_item.id,
          user_work_item.es_parent).as_indexed_json.with_indifferent_access
        expect(result).to match(
          project_id: user_work_item.reload.project_id,
          id: user_work_item.id,
          iid: user_work_item.iid,
          root_namespace_id: user_work_item.namespace_id,
          created_at: user_work_item.created_at,
          updated_at: user_work_item.updated_at,
          title: user_work_item.title,
          description: user_work_item.description,
          state: user_work_item.state,
          upvotes: user_work_item.upvotes_count,
          hidden: user_work_item.hidden?,
          work_item_type_id: user_work_item.work_item_type_id,
          confidential: user_work_item.confidential,
          author_id: user_work_item.author_id,
          label_ids: [label.id.to_s],
          assignee_id: user_work_item.issue_assignee_user_ids,
          due_date: user_work_item.due_date,
          traversal_ids: "#{user_work_item.namespace.id}-",
          hashed_root_namespace_id: user_work_item.namespace.hashed_root_namespace_id,
          namespace_visibility_level: user_work_item.namespace.visibility_level,
          schema_version: described_class::SCHEMA_VERSION,
          type: 'work_item'
        )
      end
    end
  end

  describe '#instantiate' do
    let(:work_item_ref) { described_class.new(work_item.id, work_item.es_parent) }

    context 'when work_item index is available' do
      before do
        set_elasticsearch_migration_to :create_work_items_index, including: true
      end

      it 'instantiates work item' do
        new_work_item = described_class.instantiate(work_item_ref.serialize)
        expect(new_work_item.routing).to eq(work_item.es_parent)
        expect(new_work_item.identifier).to eq(work_item.id)
      end
    end

    context 'when migration is not completed' do
      before do
        set_elasticsearch_migration_to :create_work_items_index, including: false
      end

      it 'does not instantiate work item' do
        expect(described_class.instantiate(work_item_ref.serialize)).to be_nil
      end
    end

    context 'when ff is turned off' do
      before do
        stub_feature_flags(elastic_index_work_items: false)
      end

      it 'does not instantiate work item' do
        expect(described_class.instantiate(work_item_ref.serialize)).to be_nil
      end
    end
  end

  describe '#serialize' do
    it 'returns serialized string of work item record from class method' do
      expect(described_class.serialize(work_item)).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end

    it 'returns serialized string of work item record from instance method' do
      expect(described_class.new(work_item.id,
        work_item.es_parent).serialize).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#model_klass' do
    it 'returns correct environment based index name from class' do
      expect(described_class.new(work_item.id, work_item.es_parent).model_klass).to eq(WorkItem)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name from class method' do
      expect(described_class.index).to eq('gitlab-test-work_items')
    end

    it 'returns correct environment based index name from instance method' do
      expect(described_class.new(work_item.id, work_item.es_parent).index_name).to eq('gitlab-test-work_items')
    end
  end
end
