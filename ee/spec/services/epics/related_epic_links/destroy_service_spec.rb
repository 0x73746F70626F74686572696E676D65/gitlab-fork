# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::RelatedEpicLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:public_epic) { create(:epic, group: public_group) }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:guest) { create(:user, guest_of: group) }
    let_it_be_with_reload(:source) { create(:epic, group: group) }
    let_it_be_with_reload(:target) { create(:epic, group: group) }
    let_it_be_with_refind(:issuable_link) { create(:related_epic_link, source: source, target: target) }

    let(:user) { guest }

    subject(:execute) { described_class.new(issuable_link, issuable_link.source, user).execute }

    before do
      stub_licensed_features(epics: true, related_epics: true)
    end

    it_behaves_like 'a destroyable issuable link'

    context 'with a synced work item' do
      let_it_be_with_reload(:source) { create(:epic, group: group) }
      let_it_be_with_reload(:target) { create(:epic, group: group) }
      let_it_be(:work_item_link) { create(:work_item_link, source: source.work_item, target: target.work_item) }
      let_it_be_with_refind(:issuable_link) { create(:related_epic_link, source: source, target: target) }

      it_behaves_like 'syncs all data from an epic to a work item' do
        let(:epic) { source }
      end

      context 'when epic is the source' do
        it 'removes the epic and the work item relation and does not create system notes' do
          expect { subject }.to change { issuable_link.class.count }.by(-1)
          .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)

          expect(source.reload.work_item.notes).to be_empty
          expect(target.reload.work_item.notes).to be_empty
          expect(source.updated_at).to eq(source.work_item.updated_at)
          expect(target.updated_at).to eq(target.work_item.updated_at)
        end
      end

      context 'when epic is the target' do
        subject(:execute) { described_class.new(issuable_link, issuable_link.target, user).execute }

        it 'removes the epic and the work item relation and does not create system notes' do
          expect { subject }.to change { issuable_link.class.count }.by(-1)
          .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)

          expect(source.reload.work_item.notes).to be_empty
          expect(target.reload.work_item.notes).to be_empty
        end
      end

      context 'when the source has no synced work item' do
        let_it_be_with_reload(:source) { create(:epic, :without_synced_work_item, group: group) }
        let_it_be_with_refind(:issuable_link) { create(:related_epic_link, source: source, target: target) }

        it 'removes the epic but not the work item relation' do
          expect { subject }.to change { issuable_link.class.count }.by(-1)
          .and not_change { WorkItems::RelatedWorkItemLink.count }
        end
      end

      context 'when the target has no synced work item' do
        let_it_be_with_reload(:target) { create(:epic, :without_synced_work_item, group: group) }
        let_it_be_with_refind(:issuable_link) { create(:related_epic_link, source: source, target: target) }

        it 'removes the epic but not the work item relation' do
          expect { subject }.to change { issuable_link.class.count }.by(-1)
          .and not_change { WorkItems::RelatedWorkItemLink.count }
        end
      end

      context 'when destroying the work item link fails' do
        before do
          allow_next_instance_of(WorkItems::RelatedWorkItemLinks::DestroyService) do |instance|
            allow(instance).to receive(:execute).and_return({ status: :error, message: "Some error" })
          end
        end

        it 'does not create an epic link nor a work item link', :aggregate_failures do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to destroy work item links",
              error_message: "Some error",
              group_id: group.id,
              source_id: source.id,
              target_id: target.id
            })

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError),
            { epic_id: source.id }
          )

          expect { execute }.to not_change { Epic::RelatedEpicLink.count }
            .and not_change { WorkItems::RelatedWorkItemLink.count }
        end

        it 'returns an error' do
          expect(execute)
            .to eq({ status: :error, message: "Couldn't delete link due to an internal error.", http_status: 422 })
        end
      end
    end

    context 'when user is not a guest in public source group' do
      let_it_be(:issuable_link) { create(:related_epic_link, source: public_epic, target: target) }

      it 'does not remove relation' do
        expect { subject }.not_to change { issuable_link.class.count }
      end

      it 'returns an error message' do
        is_expected.to eq(message: 'No Related Epic Link found', status: :error, http_status: 404)
      end
    end

    context 'when user is not a guest in public target group' do
      let_it_be(:issuable_link) { create(:related_epic_link, source: source, target: public_epic) }

      it 'removes relation' do
        expect { subject }.to change { issuable_link.class.count }.by(-1)
      end

      context 'and `epic_relations_for_non_members` feature flag is disabled' do
        before do
          stub_feature_flags(epic_relations_for_non_members: false)
        end

        it 'does not remove relation' do
          expect { subject }.not_to change { issuable_link.class.count }
        end

        it 'returns an error message' do
          is_expected.to eq(message: 'No Related Epic Link found', status: :error, http_status: 404)
        end
      end
    end

    context 'event tracking' do
      subject { described_class.new(issuable_link, epic, user).execute }

      let(:issuable_link) { create(:related_epic_link, link_type: link_type) }

      before do
        issuable_link.source.resource_parent.add_guest(user)
        issuable_link.target.resource_parent.add_guest(user)
      end

      shared_examples 'a recorded event' do
        it 'records event for destroyed link' do
          expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter)
            .to receive(tracking_method).with(author: user, namespace: epic.group).once

          subject
        end

        context 'when given epic is not link target or source' do
          it 'does not record any event' do
            service = described_class.new(issuable_link, create(:epic), user)

            expect(service).not_to receive(:track_related_epics_event_for)

            service.execute
          end
        end
      end

      context 'for relates_to link type' do
        let(:link_type) { IssuableLink::TYPE_RELATES_TO }

        # For TYPE_RELATES_TO we record the same event when epic is link.target or link.source
        # because there is no inverse relationship.
        let(:tracking_method) { :track_linked_epic_with_type_relates_to_removed }

        context 'when epic in context is the link source' do
          let(:epic) { issuable_link.source }

          it_behaves_like 'a recorded event'
        end

        context 'when epic in context is the link target' do
          let(:epic) { issuable_link.target }

          it_behaves_like 'a recorded event'
        end
      end

      context 'for blocks link type' do
        let(:link_type) { IssuableLink::TYPE_BLOCKS }

        context 'when epic in context is the link source' do
          let(:tracking_method) { :track_linked_epic_with_type_blocks_removed }
          let(:epic) { issuable_link.source }

          it_behaves_like 'a recorded event'
        end

        context 'when epic in context is the link target' do
          let(:tracking_method) { :track_linked_epic_with_type_is_blocked_by_removed }
          let(:epic) { issuable_link.target }

          it_behaves_like 'a recorded event'
        end
      end
    end

    context 'when synced_epic is true' do
      subject(:execute) do
        described_class.new(
          issuable_link,
          issuable_link.source,
          user,
          synced_epic: true
        ).execute
      end

      it 'does not create system notes' do
        expect { execute }.not_to change { Note.count }
      end

      context 'and user does not have permissions' do
        let(:user) { create(:user) }

        it 'skips permission checks and destroys the link' do
          expect { execute }.to change { issuable_link.class.count }.by(-1)
        end
      end
    end
  end
end
