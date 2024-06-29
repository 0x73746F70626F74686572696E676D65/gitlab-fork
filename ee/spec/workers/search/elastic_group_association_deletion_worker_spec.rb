# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ElasticGroupAssociationDeletionWorker, :elastic_helpers, feature_category: :global_search do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(group.id, parent_group.id) }

    let_it_be(:parent_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: parent_group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let(:epic_index) { Epic.__elasticsearch__.index_name }
    let(:helper) { Gitlab::Elastic::Helper.default }
    let(:client) { helper.client }

    before do
      set_elasticsearch_migration_to :create_work_items_index, including: true
    end

    context 'when indexing is paused' do
      before do
        allow(Elastic::IndexingControl).to receive(:non_cached_pause_indexing?).and_return(true)
      end

      it 'adds the job to the waiting queue' do
        expect(Elastic::IndexingControlService).to receive(:add_to_waiting_queue!)
          .with(described_class, [group.id, parent_group.id], anything).once

        perform
      end
    end

    context 'when Elasticsearch is enabled', :elastic_delete_by_query do
      let(:work_item_index) { ::Search::Elastic::Types::WorkItem.index_name }
      let(:group_work_item) { create(:work_item, namespace: group) }
      let(:sub_group_work_item) { create(:work_item, namespace: sub_group) }

      before do
        stub_ee_application_setting(elasticsearch_indexing: true)

        group_work_item
        sub_group_work_item
        ensure_elasticsearch_index!
      end

      context 'when elastic_index_work_items is disabled' do
        before do
          stub_feature_flags(elastic_index_work_items: false)
        end

        it 'does not remove work items' do
          # items are present already
          expect(items_in_index(index_name: work_item_index).count).to eq(2)
          expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
          expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)

          described_class.new.perform(group.id, parent_group.id)
          helper.refresh_index(index_name: work_item_index)

          # work items not removed
          expect(items_in_index(index_name: work_item_index).count).to eq(2)
          expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
          expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)
        end
      end

      context 'when migration is not complete' do
        before do
          set_elasticsearch_migration_to :create_work_items_index, including: false
        end

        it 'does not remove work items' do
          # items are present already
          expect(items_in_index(index_name: work_item_index).count).to eq(2)
          expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
          expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)

          described_class.new.perform(group.id, parent_group.id)
          helper.refresh_index(index_name: work_item_index)

          # work items not removed
          expect(items_in_index(index_name: work_item_index).count).to eq(2)
          expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
          expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)
        end
      end

      context 'when work_item index is available' do
        context 'when we pass include_descendants' do
          it 'deletes work items belonging to the group and its descendants' do
            # items are present already
            expect(items_in_index(index_name: work_item_index).count).to eq(2)
            expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
            expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)

            described_class.new.perform(group.id, parent_group.id, { include_descendants: true })
            helper.refresh_index(index_name: work_item_index)

            # items are deleted
            expect(items_in_index(index_name: work_item_index).count).to eq(0)
          end
        end

        context 'when we do not pass include_descendants' do
          it 'deletes work_items belonging to the group' do
            # items are present already
            expect(items_in_index(index_name: work_item_index).count).to eq(2)
            expect(items_in_index(index_name: work_item_index)).to include(group_work_item.id)
            expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)

            described_class.new.perform(group.id, parent_group.id)
            helper.refresh_index(index_name: work_item_index)

            # sub group work item is present
            expect(items_in_index(index_name: work_item_index).count).to eq(1)
            expect(items_in_index(index_name: work_item_index)).to include(sub_group_work_item.id)
          end
        end
      end

      context 'when Epic indexing is available' do
        let(:group_epic) { create(:epic, group: group) }
        let(:sub_group_epic) { create(:epic, group: sub_group) }

        before do
          allow(Epic).to receive(:elasticsearch_available?).and_return(true)
          stub_licensed_features(epics: true)
          group_epic
          sub_group_epic
          ensure_elasticsearch_index!
        end

        context 'when we pass include_descendants' do
          it 'deletes epics belonging to the group and its descendants' do
            # items are present already
            expect(items_in_index.count).to eq(2)
            expect(items_in_index).to include(group_epic.id)
            expect(items_in_index).to include(sub_group_epic.id)

            described_class.new.perform(group.id, parent_group.id, { include_descendants: true })
            helper.refresh_index(index_name: epic_index)

            # items are deleted
            expect(items_in_index.count).to eq(0)
          end
        end

        context 'when we do not pass include_descendants' do
          it 'deletes epics belonging to the group' do
            # items are present already
            expect(items_in_index.count).to eq(2)
            expect(items_in_index).to include(group_epic.id)
            expect(items_in_index).to include(sub_group_epic.id)

            described_class.new.perform(group.id, parent_group.id)
            helper.refresh_index(index_name: epic_index)

            # sub group epic is present
            expect(items_in_index.count).to eq(1)
            expect(items_in_index).not_to include(group_epic.id)
          end
        end

        context 'when licensed_feature is not available' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'does not delete epics' do
            # items are present already
            expect(items_in_index.count).to eq(2)
            expect(items_in_index).to include(group_epic.id)
            expect(items_in_index).to include(sub_group_epic.id)

            perform
            helper.refresh_index(index_name: epic_index)

            # items are not deleted
            expect(items_in_index.count).to eq(2)
            expect(items_in_index).to include(group_epic.id)
            expect(items_in_index).to include(sub_group_epic.id)
          end
        end
      end
    end
  end

  def items_in_index(index_name: epic_index)
    client.search(index: index_name).dig('hits', 'hits').map { |hit| hit['_source']['id'] }
  end
end
