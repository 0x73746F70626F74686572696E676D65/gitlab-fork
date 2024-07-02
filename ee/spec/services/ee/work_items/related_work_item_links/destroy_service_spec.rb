# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::RelatedWorkItemLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:project) { create(:project_empty_repo, :private) }
    let_it_be(:user) { create(:user) }
    let_it_be(:source) { create(:work_item, project: project) }
    let_it_be(:linked_item) { create(:work_item, project: project) }

    let_it_be(:link) { create(:work_item_link, source: source, target: linked_item) }

    let(:extra_params) { {} }
    let(:ids_to_remove) { [linked_item.id] }

    subject(:destroy_links) do
      described_class.new(source, user, { item_ids: ids_to_remove, extra_params: extra_params }).execute
    end

    before_all do
      project.add_guest(user)
    end

    context 'when synced_work_item: true' do
      let(:extra_params) { { synced_work_item: true } }

      it 'does not create a system note' do
        expect(SystemNoteService).not_to receive(:unrelate_issuable)

        expect { destroy_links }.not_to change { SystemNoteMetadata.count }
      end
    end

    context 'when there is an epic for the work item' do
      let_it_be(:group) { create(:group) }
      let_it_be(:epic_a) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:epic_b) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:source) { epic_a.work_item }
      let_it_be(:target) { epic_b.work_item }
      let_it_be(:link) { create(:work_item_link, source: source, target: target) }
      let_it_be(:related_epic_link) { create(:related_epic_link, source: epic_a, target: epic_b) }

      let_it_be(:ids_to_remove) { [target.id] }

      before_all do
        group.add_guest(user)
      end

      before do
        stub_licensed_features(epics: true, related_epics: true)
      end

      context 'when synced_epic_work_item_editable is disabled' do
        before do
          stub_feature_flags(synced_epic_work_item_editable: false)
        end

        it 'does not destroy the links' do
          expect { destroy_links }.to not_change { WorkItems::RelatedWorkItemLink.count }
        end
      end

      context 'when synced_work_item: true' do
        let(:extra_params) { { synced_work_item: true } }

        it 'skips the permission check' do
          expect { destroy_links }.to change { WorkItems::RelatedWorkItemLink.count }.by(-1)
        end

        it 'does not destroy related epic link' do
          expect(::Epics::RelatedEpicLinks::DestroyService).not_to receive(:new)

          expect { destroy_links }.not_to change { Epic::RelatedEpicLink.count }
        end
      end

      context 'when synced_work_item: false' do
        before do
          stub_feature_flags(synced_epic_work_item_editable: true)
        end

        it 'creates system notes' do
          expect(SystemNoteService).to receive(:unrelate_issuable).with(source, target, user)
          expect(SystemNoteService).to receive(:unrelate_issuable).with(target, source, user)

          destroy_links
        end

        it 'destroys both links' do
          expect { destroy_links }.to change { WorkItems::RelatedWorkItemLink.count }.by(-1)
            .and change { Epic::RelatedEpicLink.count }.by(-1)

          expect(epic_a.related_epics(user)).to be_empty
          expect(source.linked_work_items(authorize: false)).to be_empty
        end

        it 'calls this service once' do
          allow(described_class).to receive(:new).and_call_original
          expect(described_class).to receive(:new).once

          destroy_links
        end

        it 'creates notes only for work item', :sidekiq_inline do
          expect { destroy_links }.to change { Epic::RelatedEpicLink.count }.by(-1)
            .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)
            .and change { source.notes.count }.by(1)
            .and change { target.notes.count }.by(1)
            .and not_change { epic_a.own_notes.count }
            .and not_change { epic_b.own_notes.count }
        end

        context 'when destroying the related epic link fails' do
          before do
            allow_next_instance_of(Epics::RelatedEpicLinks::DestroyService) do |instance|
              allow(instance).to receive(:execute).and_return({ status: :error, message: "Some error" })
            end
          end

          it 'does not create an epic link nor a work item link', :aggregate_failures do
            expect(::Gitlab::EpicWorkItemSync::Logger).to receive(:error)
              .with({
                message: 'Not able to destroy related epic links',
                error_message: 'Some error',
                group_id: group.id,
                source_id: source.id,
                target_id: target.id
              })

            expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(::WorkItems::SyncAsEpic::SyncAsEpicError),
              { work_item_id: source.id }
            )

            expect { destroy_links }.to not_change { Epic::RelatedEpicLink.count }
              .and not_change { WorkItems::RelatedWorkItemLink.count }
          end

          it 'returns an error' do
            expect(destroy_links)
              .to eq({ status: :error, message: "Couldn't delete work item link due to an internal error.",
http_status: 422 })
          end
        end
      end
    end
  end
end
