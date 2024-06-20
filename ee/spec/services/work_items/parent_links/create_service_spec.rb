# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ParentLinks::CreateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, reporters: user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:work_item1) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item2) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item_issue) { create(:work_item, :issue, project: project) }
    let_it_be(:parent_epic) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:other_parent_epic) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:other_child_epic) { create(:epic, :with_synced_work_item, parent: other_parent_epic, group: group) }

    let(:params) { { issuable_references: [child_work_item], synced_work_item: synced_work_item_param } }

    subject(:create_link) { described_class.new(parent_work_item, user, params).execute }

    before do
      stub_licensed_features(subepics: true)
    end

    shared_examples 'does not create parent link' do
      it 'no relationship is created' do
        expect { create_link }.not_to change { WorkItems::ParentLink.count }
      end

      it 'returns error' do
        is_expected.to eq({
          http_status: 404,
          status: :error,
          message: 'No matching work item found. Make sure that you are adding a valid work item ID.'
        })
      end
    end

    shared_examples 'creates parent link only' do |system_notes_count: 2|
      it 'creates parent link without calling legacy epic services' do
        allow(::Epics::EpicLinks::CreateService).to receive(:new).and_call_original
        allow(::EpicIssues::CreateService).to receive(:new).and_call_original

        expect(::Epics::EpicLinks::CreateService).not_to receive(:new)
        expect(::EpicIssues::CreateService).not_to receive(:new)
        expect { create_link }.to change { WorkItems::ParentLink.count }.by(1)
                              .and change { Note.count }.by(system_notes_count)
      end
    end

    shared_examples 'creates parent link and deletes legacy link' do
      let(:create_service) { "#{link_service_class}::CreateService".constantize }
      let(:destroy_service) { "#{link_service_class}::DestroyService".constantize }

      it 'creates parent link and remove previous legacy parent epic' do
        allow(create_service).to receive(:new).and_call_original
        allow(destroy_service).to receive(:new).and_call_original
        expect(create_service).not_to receive(:new)
        expect(destroy_service).to receive(:new)

        expect { create_link }.to change { child_work_item.reload.work_item_parent }.to(parent_work_item)
          .and change { legacy_child.reload.try(relationship) }.to(nil)
          .and change { Note.count }.by(2)

        full_reference = child_work_item.namespace != parent_work_item.namespace

        expect(parent_work_item.notes.first.note).to eq(
          "added #{child_work_item.to_reference(full: full_reference)} as child #{legacy_child.model_name.element}"
        )
        expect(child_work_item.notes.first.note)
          .to eq("added #{parent_work_item.to_reference(full: full_reference)} as parent epic")
      end
    end

    shared_examples 'link creation with failures' do
      context 'when creating legacy epic link fails' do
        before do
          allow_next_instance_of(link_service_class) do |instance|
            allow(instance).to receive(:execute).and_return({ status: :error, message: 'Some error' })
          end
        end

        it 'does not create a work item parent link or set the parent epic' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: 'Not able to create work item parent link',
              error_message: 'Some error',
              group_id: group.id,
              work_item_parent_id: parent_work_item.id,
              work_item_id: child_work_item.id
            })

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(WorkItems::SyncAsEpic::SyncAsEpicError),
            { work_item_parent_id: parent_work_item.id }
          )

          expect { create_link }.to not_change { WorkItems::ParentLink.count }
                                .and not_change { legacy_child.reload.try(relationship) }

          expect(create_link)
            .to eq({ status: :error, message: "Couldn't create link due to an internal error.", http_status: 422 })
        end
      end

      context 'when creating parent link fails' do
        before do
          allow_next_instance_of(::WorkItems::ParentLink) do |instance|
            allow(instance).to receive(:save).and_return(false)

            errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:work_item, 'error message') }
            allow(instance).to receive(:errors).and_return(errors)
          end
        end

        it 'does not create a parent work item link or set parent epic' do
          error_message = "#{child_work_item.to_reference} cannot be added: error message"

          expect { create_link }.to not_change { WorkItems::ParentLink.count }
                                .and not_change { legacy_child.reload.try(relationship) }

          expect(create_link).to eq(message: error_message, status: :error, http_status: 422)
        end
      end
    end

    context 'when epic work item type' do
      context 'when subepics are not available' do
        let(:synced_work_item_param) { false }
        let(:parent_work_item) { work_item1 }
        let(:child_work_item) { work_item2 }

        before do
          stub_licensed_features(subepics: false)
        end

        it_behaves_like 'does not create parent link'
      end
    end

    context "when parent and child work items don't have a synced epic" do
      let(:parent_work_item) { work_item1 }
      let(:child_work_item) { work_item2 }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        it_behaves_like 'creates parent link only'

        context 'when synced_epic_work_item_editable feature flag is enabled' do
          before do
            stub_feature_flags(synced_epic_work_item_editable: true)
          end

          it_behaves_like 'creates parent link only'

          context 'when issue already has an epic' do
            let(:child_work_item) { work_item_issue }
            let(:child_issue) { Issue.find_by_id(child_work_item.id) }

            before do
              create(:epic_issue, issue: child_work_item, epic: other_parent_epic)
            end

            it_behaves_like 'creates parent link and deletes legacy link' do
              let(:legacy_child) { child_issue }
              let(:relationship) { :epic }
              let(:link_service_class) { ::EpicIssues }
            end
          end
        end
      end
    end

    context 'when only parent work item has a synced epic' do
      let_it_be(:parent_work_item) { parent_epic.work_item }
      let(:child_work_item) { work_item2 }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        it_behaves_like 'does not create parent link'

        context 'when synced_epic_work_item_editable feature flag is enabled' do
          let_it_be(:other_epic_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:other_epic_work_item_link) do
            create(:parent_link, work_item: other_epic_work_item, work_item_parent: parent_work_item,
              relative_position: 500)
          end

          before_all do
            other_epic_work_item.synced_epic.update!(parent: parent_epic, relative_position: 500)
          end

          before do
            stub_feature_flags(synced_epic_work_item_editable: true)
          end

          context 'when child is type :epic' do
            it_behaves_like 'creates parent link only'
          end

          context 'when child is type :issue' do
            let(:child_work_item) { work_item_issue }
            let(:child_issue) { Issue.find(child_work_item.id) }

            let_it_be(:other_issue_work_item) { create(:work_item, :issue, namespace: group) }
            let_it_be(:other_issue_work_item_link) do
              create(:parent_link, work_item: other_issue_work_item, work_item_parent: parent_work_item,
                relative_position: 600)
            end

            let_it_be(:other_issue_epic_issue) do
              create(:epic_issue, issue: other_issue_work_item, epic: parent_work_item.synced_epic,
                relative_position: 600)
            end

            it 'calls this service once' do
              allow(described_class).to receive(:new).and_call_original
              expect(described_class).to receive(:new).once

              create_link
            end

            it 'syncs parent epic and creates notes only for the work items', :aggregate_failures do
              expect { create_link }.to change { child_issue.reload.epic }.to(parent_epic)
                .and change { WorkItems::ParentLink.count }.by(1)
                .and change { Note.count }.by(2)
                .and not_change { parent_epic.reload.notes.count }

              expect(child_issue.epic_issue.relative_position).to eq(child_work_item.parent_link.relative_position)

              expect(parent_work_item.reload.notes.last.note)
                .to eq("added #{child_work_item.to_reference(full: true)} as child issue")
              expect(child_work_item.reload.notes.last.note)
                .to eq("added #{parent_work_item.to_reference(full: true)} as parent epic")
            end

            context 'when sync_work_item_to_epic feature flag is disabled' do
              before do
                stub_feature_flags(sync_work_item_to_epic: false)
              end

              it_behaves_like 'creates parent link only'

              context 'when issue already has an epic' do
                let(:child_work_item) { work_item_issue }
                let(:child_issue) { Issue.find_by_id(child_work_item.id) }

                before do
                  create(:epic_issue, issue: child_work_item, epic: other_parent_epic)
                end

                it_behaves_like 'creates parent link and deletes legacy link' do
                  let(:legacy_child) { child_issue }
                  let(:relationship) { :epic }
                  let(:link_service_class) { ::EpicIssues }
                end
              end
            end

            it_behaves_like 'link creation with failures' do
              let(:link_service_class) { ::EpicIssues::CreateService }
              let(:legacy_child) { child_issue }
              let(:relationship) { :epic }
            end
          end
        end
      end
    end

    context 'when only child work item has a synced epic' do
      let(:parent_work_item) { work_item1 }
      let(:child_work_item) { parent_epic.work_item }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        it_behaves_like 'does not create parent link'

        context 'when synced_epic_work_item_editable feature flag is enabled' do
          before do
            stub_feature_flags(synced_epic_work_item_editable: true)
          end

          it_behaves_like 'creates parent link only'

          context 'when legacy epic already has a parent epic' do
            let(:child_work_item) { other_child_epic.work_item }

            before do
              create(:parent_link, work_item_parent: other_parent_epic.work_item, work_item: child_work_item)
            end

            it_behaves_like 'creates parent link and deletes legacy link' do
              let(:legacy_child) { other_child_epic }
              let(:relationship) { :parent }
              let(:link_service_class) { ::Epics::EpicLinks }
            end
          end
        end
      end
    end

    context 'when both work items have a synced epic' do
      let_it_be(:child_epic) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:parent_work_item) { parent_epic.work_item }
      let(:child_work_item) { child_epic.work_item }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        it_behaves_like 'does not create parent link'

        context 'when synced_epic_work_item_editable feature flag is enabled' do
          let_it_be(:other_epic_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
          let_it_be(:other_epic_work_item_link) do
            create(:parent_link, work_item: other_epic_work_item, work_item_parent: parent_work_item,
              relative_position: 500)
          end

          before_all do
            other_epic_work_item.synced_epic.update!(parent: parent_epic, relative_position: 500)
          end

          before do
            stub_feature_flags(synced_epic_work_item_editable: true)
          end

          context 'when child is type :epic' do
            it 'calls this service once' do
              allow(described_class).to receive(:new).and_call_original
              expect(described_class).to receive(:new).once

              create_link
            end

            it 'syncs parent epic and creates notes only for the work items' do
              expect { create_link }.to change { child_epic.reload.parent }.to(parent_epic)
                .and change { WorkItems::ParentLink.count }.by(1)
                .and change { Note.count }.by(2)
                .and not_change { parent_epic.notes.count }
                .and not_change { child_epic.notes.count }

              expect(child_epic.relative_position).to eq(child_work_item.parent_link.relative_position)

              expect(parent_work_item.notes.last.note).to eq("added #{child_work_item.to_reference} as child epic")
              expect(child_work_item.notes.last.note).to eq("added #{parent_work_item.to_reference} as parent epic")
            end

            context 'when sync_work_item_to_epic feature flag is disabled' do
              before do
                stub_feature_flags(sync_work_item_to_epic: false)
              end

              it_behaves_like 'creates parent link only'

              context 'when legacy epic already has a parent epic' do
                let(:child_work_item) { other_child_epic.work_item }

                before do
                  create(:parent_link, work_item_parent: other_parent_epic.work_item,
                    work_item: child_work_item)
                end

                it_behaves_like 'creates parent link and deletes legacy link' do
                  let(:legacy_child) { other_child_epic }
                  let(:relationship) { :parent }
                  let(:link_service_class) { ::Epics::EpicLinks }
                end
              end
            end

            it_behaves_like 'link creation with failures' do
              let(:link_service_class) { ::Epics::EpicLinks::CreateService }
              let(:legacy_child) { child_epic }
              let(:relationship) { :parent }
            end
          end
        end
      end
    end
  end
end
