# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::WorkItem, :elastic_helpers, feature_category: :global_search do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, :opened, labels: [label], namespace: group) }

  describe '#as_indexed_json' do
    subject { described_class.new(work_item.id, work_item.es_parent) }

    let(:result) { subject.as_indexed_json.with_indifferent_access }

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
