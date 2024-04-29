# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::EpicLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:child_epic_group) { create(:group, :private) }
    let_it_be(:parent_epic_group) { create(:group, :private) }
    let_it_be_with_reload(:parent_epic) { create(:epic, group: parent_epic_group) }
    let_it_be_with_reload(:child_epic) { create(:epic, parent: parent_epic, group: child_epic_group) }

    shared_examples 'system notes created' do
      it 'creates system notes' do
        expect { subject }.to change { Note.system.count }.from(0).to(2)
      end
    end

    shared_examples 'returns success' do
      it 'removes epic relationship' do
        expect { subject }.to change { parent_epic.children.count }.by(-1)

        expect(parent_epic.reload.children).not_to include(child_epic)
      end

      it 'returns success status' do
        expect(subject).to eq(message: 'Relation was removed', status: :success)
      end
    end

    shared_examples 'returns not found error' do
      it 'returns an error' do
        expect(subject).to eq(message: 'No Epic found for given params', status: :error, http_status: 404)
      end

      it 'no relationship is created' do
        expect { subject }.not_to change { parent_epic.children.count }
      end

      it 'does not create system notes' do
        expect { subject }.not_to change { Note.system.count }
      end
    end

    def remove_epic_relation(child_epic)
      described_class.new(child_epic, user).execute
    end

    context 'when epics feature is disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      subject { remove_epic_relation(child_epic) }

      include_examples 'returns not found error'
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when the user has no access to parent epic' do
        subject { remove_epic_relation(child_epic) }

        before_all do
          child_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'

        context 'when `epic_relations_for_non_members` feature flag is disabled' do
          let_it_be(:child_epic_group) { create(:group, :public) }

          before do
            stub_feature_flags(epic_relations_for_non_members: false)
          end

          include_examples 'returns not found error'
        end
      end

      context 'when the user has no access to child epic' do
        subject { remove_epic_relation(child_epic) }

        before_all do
          parent_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'
      end

      context 'when user has permissions to remove epic relation' do
        before_all do
          child_epic_group.add_guest(user)
          parent_epic_group.add_guest(user)
        end

        context 'when the child epic is nil' do
          subject { remove_epic_relation(nil) }

          include_examples 'returns not found error'
        end

        context 'when a correct reference is given' do
          subject { remove_epic_relation(child_epic) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when epic has no parent' do
          subject { remove_epic_relation(parent_epic) }

          include_examples 'returns not found error'
        end

        context 'when epic has synced work item' do
          let_it_be(:parent) { create(:work_item, :epic, namespace: child_epic_group) }
          let_it_be(:child) { create(:work_item, :epic, namespace: child_epic_group) }
          let_it_be(:parent_link) { create(:parent_link, work_item_parent: parent, work_item: child) }

          before_all do
            child_epic_group.add_reporter(user)
            child_epic.update!(issue_id: child.id)
            parent_epic.update!(issue_id: parent.id)
          end

          it 'removes epic relationship and destroy work item parent link' do
            expect { remove_epic_relation(child_epic) }.to change { parent_epic.children.count }.by(-1)
              .and(change { WorkItems::ParentLink.count }.by(-1))

            expect(parent_epic.reload.children).not_to include(child_epic)
            expect(parent.reload.work_item_children).not_to include(child)
            expect(parent_epic.updated_at).to eq(parent_epic.work_item.updated_at)
            expect(child_epic.updated_at).to eq(child_epic.work_item.updated_at)
          end

          it 'does not create resource event for the work item' do
            expect(WorkItems::ResourceLinkEvent).not_to receive(:create)

            expect { remove_epic_relation(child_epic) }.to change { parent_epic.children.count }.by(-1)
              .and(change { WorkItems::ParentLink.count }.by(-1))
          end

          it 'creates system notes only for the epics' do
            expect { remove_epic_relation(child_epic) }.to change { Note.system.count }.by(2)
            expect(parent_epic.notes.last.note).to eq("removed child epic #{child_epic.to_reference(full: true)}")
            expect(child_epic.notes.last.note).to eq("removed parent epic #{parent_epic.to_reference(full: true)}")
          end

          context 'when removing child epic fails' do
            before do
              allow(child_epic).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(child_epic), 'error')
            end

            it 'raises an error and does not remove relationships' do
              expect { remove_epic_relation(child_epic) }.to raise_error ActiveRecord::RecordInvalid
              expect(parent_epic.reload.children).to include(child_epic)
              expect(parent.reload.work_item_children).to include(child)
            end
          end

          context 'when destroying work item parent link fails' do
            before do
              allow_next_instance_of(::WorkItems::ParentLinks::DestroyService) do |service|
                allow(service).to receive(:execute).and_return({ status: :error, message: 'error message' })
              end
            end

            it 'does not remove parent epic or destroy work item parent link' do
              expect { remove_epic_relation(child_epic) }.to not_change { parent_epic.children.count }
                .and(not_change { WorkItems::ParentLink.count })

              expect(parent_epic.reload.children).to include(child_epic)
              expect(parent.reload.work_item_children).to include(child)
            end

            it 'logs error' do
              allow(Gitlab::EpicWorkItemSync::Logger).to receive(:error).and_call_original
              expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error).with({
                child_id: child_epic.id,
                error_message: 'error message',
                group_id: child_epic.group.id,
                message: 'Not able to remove epic parent',
                parent_id: parent_epic.id
              })

              remove_epic_relation(child_epic)
            end
          end

          context 'when sync_epic_to_work_item feature flag is disabled' do
            before do
              stub_feature_flags(sync_epic_to_work_item: false)
            end

            it 'removes epic relationship and destroy work item parent link' do
              expect { remove_epic_relation(child_epic) }.to change { parent_epic.children.count }.by(-1)
                .and(change { WorkItems::ParentLink.count }.by(-1))

              expect(parent_epic.reload.children).not_to include(child_epic)
              expect(parent.reload.work_item_children).not_to include(child)
            end
          end

          context 'when synced_epic argument is true' do
            it 'does not call WorkItems::ParentLinks::DestroyService nor create notes' do
              allow(::WorkItems::ParentLinks::DestroyService).to receive(:new).and_call_original
              expect(::WorkItems::ParentLinks::DestroyService).not_to receive(:new)

              expect { described_class.new(child_epic, user, synced_epic: true).execute }
                .to change { parent_epic.children.count }.by(-1)
                .and(not_change { WorkItems::ParentLink.count })
                .and(not_change { Note.count })
            end
          end
        end
      end
    end
  end
end
