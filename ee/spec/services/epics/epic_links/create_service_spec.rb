# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::EpicLinks::CreateService, feature_category: :portfolio_management do
  include NestedEpicsHelper

  describe '#execute' do
    let_it_be(:ancestor) { create(:group) }
    let_it_be(:group) { create(:group, parent: ancestor) }
    let_it_be(:user) { create(:user) }
    let_it_be(:other_group) { create(:group) }

    let(:epic) { create(:epic, group: group) }
    let(:epic_to_add) { create(:epic, group: group) }
    let(:expected_error) { 'No matching epic found. Make sure that you are adding a valid epic URL.' }
    let(:expected_code) { 404 }

    let(:valid_reference) { epic_to_add.to_reference(full: true) }

    shared_examples 'system notes created' do
      it 'creates system notes' do
        expect { subject }.to change { Note.system.count }.from(0).to(2)
      end
    end

    shared_examples 'returns success' do
      it 'creates a new relationship and updates epic' do
        expect { subject }.to change { epic.children.count }.by(1)

        expect(epic.reload.children).to include(epic_to_add)
      end

      it 'moves the new child epic to the top and moves the existing ones down' do
        existing_child_epic = create(:epic, group: group, parent: epic, relative_position: 1000)

        subject

        expect(epic_to_add.reload.relative_position).to be < existing_child_epic.reload.relative_position
      end

      it 'returns success status and created links', :aggregate_failures do
        expect(subject.keys).to match_array([:status, :created_references])
        expect(subject[:status]).to eq(:success)
        expect(subject[:created_references]).to match_array([epic_to_add])
      end
    end

    shared_examples 'returns an error' do
      it 'returns an error' do
        expect(subject).to eq(message: expected_error, status: :error, http_status: expected_code)
      end

      it 'no relationship is created' do
        expect { subject }.not_to change { epic.children.count }
      end
    end

    def add_epic(references)
      params = { issuable_references: references }

      described_class.new(epic, user, params).execute
    end

    context 'when subepics feature is disabled' do
      before do
        stub_licensed_features(epics: true, subepics: false)
      end

      subject { add_epic([valid_reference]) }

      include_examples 'returns an error'
    end

    context 'when subepics feature is enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when an error occurs' do
        context 'when a single epic is given' do
          subject { add_epic([valid_reference]) }

          context 'when user does not have create_epic_tree_relation access for the parent' do
            before do
              group.add_guest(user)
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?)
                                  .with(user, :create_epic_tree_relation, epic).and_return(false)
            end

            include_examples 'returns an error'
          end

          context 'when a user has permissions to add an epic' do
            before do
              group.add_guest(user)
            end

            context 'when an epic from another group is given' do
              before do
                epic_to_add.update!(group: other_group)
              end

              context 'when user has no permission to admin_epic_tree_relation' do
                let(:params) { { target_issuable: epic_to_add } }

                subject { described_class.new(epic, user, params).execute }

                before do
                  other_group.add_guest(user)
                  epic_to_add.update!(confidential: true)
                end

                include_examples 'returns an error'
              end

              context 'when subepics feature is not available for child group' do
                before do
                  other_group.add_guest(user)
                  stub_licensed_features(epics: true)

                  allow(group).to receive(:licensed_feature_available?).and_return(true)
                  allow(other_group).to receive(:licensed_feature_available?).with(:subepics).and_return(false)
                end

                include_examples 'returns an error'
              end
            end

            context 'when hierarchy is cyclic' do
              context 'when given child epic is the same as given parent' do
                let(:expected_error) { "This epic cannot be added. An epic cannot be added to itself." }
                let(:expected_code) { 409 }

                subject { add_epic([epic.to_reference(full: true)]) }

                include_examples 'returns an error'
              end

              context 'when given child epic is parent of the given parent' do
                let(:expected_error) { "This epic cannot be added. It is already an ancestor of the parent epic." }
                let(:expected_code) { 409 }

                before do
                  epic.update!(parent: epic_to_add)
                end

                include_examples 'returns an error'
              end

              context 'when new child epic is an ancestor of the given parent' do
                let(:expected_error) { "This epic cannot be added. It is already an ancestor of the parent epic." }
                let(:expected_code) { 409 }

                before do
                  # epic_to_add -> epic1 -> epic2 -> epic
                  epic1 = create(:epic, group: group, parent: epic_to_add)
                  epic2 = create(:epic, group: group, parent: epic1)
                  epic.update!(parent: epic2)
                end

                include_examples 'returns an error'
              end
            end

            context 'when adding an epic that is already a child of the parent epic' do
              before do
                epic_to_add.update!(parent: epic)
              end

              let(:expected_error) { "This epic cannot be added. It is already assigned to the parent epic." }
              let(:expected_code) { 409 }

              include_examples 'returns an error'
            end

            context 'when adding to an Epic that is already at maximum depth' do
              before do
                add_parents_to(epic: epic, count: 6)
              end

              let(:expected_code) { 409 }
              let(:expected_error) do
                "This epic cannot be added. One or more epics would exceed the "\
                "maximum depth (#{Epic::MAX_HIERARCHY_DEPTH}) from its most "\
                "distant ancestor."
              end

              include_examples 'returns an error'
            end

            context 'when total depth after adding would exceed depth limit' do
              let(:expected_code) { 409 }
              let(:expected_error) do
                "This epic cannot be added. One or more epics would exceed the "\
                "maximum depth (#{Epic::MAX_HIERARCHY_DEPTH}) from its most "\
                "distant ancestor."
              end

              before do
                add_parents_to(epic: epic, count: 1) # epic is on level 2

                # epic_to_add has 5 children (level 6 including epic_to_add)
                # that would mean level 8 after relating epic_to_add on epic
                add_children_to(epic: epic_to_add, count: 5)
              end

              include_examples 'returns an error'
            end

            context 'when total children count after adding would exceed limit' do
              let(:expected_error) do
                "You cannot add any more epics. This epic already has maximum "\
                "number of child epics."
              end

              let(:expected_code) { 409 }

              before do
                create(:epic, group: group, parent: epic)
                stub_const("EE::Epic::MAX_CHILDREN_COUNT", 1)
              end

              include_examples 'returns an error'
            end
          end
        end

        context 'when multiple epics are given' do
          let_it_be(:another_epic) { create(:epic, group: ancestor) }

          subject do
            add_epic(
              [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)]
            )
          end

          context 'when user does not have create_epic_tree_relation access for the parent' do
            before do
              group.add_guest(user)
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?)
                                  .with(user, :create_epic_tree_relation, epic).and_return(false)
            end

            include_examples 'returns an error'
          end

          context 'when a user has permissions to add an epic' do
            before do
              group.add_developer(user)
            end

            context 'when adding epics that are already a child of the parent epic' do
              let(:expected_error) { 'Epic(s) already assigned' }
              let(:expected_code) { 409 }

              before do
                epic_to_add.update!(parent: epic)
                another_epic.update!(parent: epic)
              end

              include_examples 'returns an error'
            end

            context 'when total depth after adding would exceed limit' do
              before do
                add_parents_to(epic: epic, count: 1) # epic is on level 2

                # epic_to_add has 5 children (level 6 including epic_to_add)
                # that would mean level 8 after relating epic_to_add on epic
                add_children_to(epic: epic_to_add, count: 5)
              end

              include_examples 'returns an error'
            end

            context 'when an epic from a another group is given' do
              before do
                epic_to_add.update!(group: other_group)
              end

              context 'when user has insufficient permissions' do
                include_examples 'returns an error'
              end

              context 'when subepics feature is not available for child group' do
                before do
                  other_group.add_guest(user)
                  stub_licensed_features(epics: true)

                  allow(group).to receive(:licensed_feature_available?).and_return(true)
                  allow(other_group).to receive(:licensed_feature_available?).with(:subepics).and_return(false)
                end

                include_examples 'returns an error'
              end
            end

            context 'when hierarchy is cyclic' do
              context 'when given child epic is the same as given parent' do
                subject { add_epic([epic.to_reference(full: true), another_epic.to_reference(full: true)]) }

                include_examples 'returns an error'
              end

              context 'when given child epic is parent of the given parent' do
                before do
                  epic.update!(parent: epic_to_add)
                end

                include_examples 'returns an error'
              end
            end

            context 'when the reference list is empty' do
              subject { add_epic([]) }

              include_examples 'returns an error'
            end

            context 'when there are invalid references' do
              let_it_be(:epic) { create(:epic, confidential: true, group: group) }
              let_it_be(:invalid_epic1) { create(:epic, group: group) }
              let_it_be(:valid_epic) { create(:epic, :confidential, group: group) }
              let_it_be(:invalid_epic2) { create(:epic, group: group) }

              subject do
                add_epic([invalid_epic1.to_reference(full: true),
                          valid_epic.to_reference(full: true),
                          invalid_epic2.to_reference(full: true)])
              end

              it 'adds only valid references' do
                subject

                expect(epic.reload.children).to match_array([valid_epic])
              end

              it 'returns error status' do
                expect(subject).to eq(
                  status: :error,
                  http_status: 422,
                  message: "#{invalid_epic1.to_reference} cannot be added: A non-confidential "\
                           "epic cannot be assigned to a confidential parent epic. "\
                           "#{invalid_epic2.to_reference} cannot be added: A non-confidential "\
                           "epic cannot be assigned to a confidential parent epic"
                )
              end
            end
          end
        end
      end

      context 'when everything is ok' do
        let_it_be_with_reload(:another_epic) { create(:epic, group: group) }

        before do
          group.add_guest(user)
        end

        context 'when a correct reference is given' do
          subject { add_epic([valid_reference]) }

          include_examples 'returns success'
          include_examples 'system notes created'

          context 'when parent has inherited dates' do
            let_it_be(:other_parent) do
              create(
                :epic, group: group, start_date: 1.day.ago, due_date: 1.day.from_now,
                start_date_is_fixed: false, due_date_is_fixed: false
              )
            end

            let_it_be(:epic_to_add) do
              create(:epic, group: group, start_date: 1.day.ago, due_date: 1.day.from_now, parent: other_parent)
            end

            before do
              epic.update!(start_date: nil, due_date: nil, start_date_is_fixed: false, due_date_is_fixed: false)
            end

            it 'updates the parent dates' do
              expect { subject }.to change { epic.reload.children.count }.by(1)
                                .and change { epic.start_date }.from(nil).to(epic_to_add.start_date)
                                .and change { epic.due_date }.from(nil).to(epic_to_add.due_date)
                                .and change { epic.start_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                                .and change { epic.due_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                                .and change { other_parent.reload.children.count }.by(-1)
                                .and change { other_parent.start_date }.from(epic_to_add.start_date).to(nil)
                                .and change { other_parent.due_date }.from(epic_to_add.due_date).to(nil)
            end
          end
        end

        context 'when an epic from a subgroup is given' do
          let_it_be(:subgroup) { create(:group, parent: group) }

          before do
            epic_to_add.update!(group: subgroup)
          end

          subject { add_epic([valid_reference]) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when an epic from another group is given' do
          before do
            epic_to_add.update!(group: other_group)
            other_group.add_reporter(user)
          end

          subject { add_epic([valid_reference]) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when an epic from ancestor group is given' do
          before do
            ancestor.add_guest(user)
            epic_to_add.update!(group: ancestor)
          end

          subject { add_epic([valid_reference]) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when multiple valid epics are given' do
          subject do
            add_epic(
              [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)]
            )
          end

          it 'creates new relationships' do
            expect { subject }.to change { epic.children.count }.by(2)

            expect(epic.reload.children).to match_array([epic_to_add, another_epic])
          end

          it 'creates system notes' do
            expect { subject }.to change { Note.system.count }.from(0).to(4)
          end

          it 'returns success status and created links', :aggregate_failures do
            expect(subject.keys).to match_array([:status, :created_references])
            expect(subject[:status]).to eq(:success)
            expect(subject[:created_references]).to match_array([epic_to_add, another_epic])
          end

          it 'avoids un-necessary database queries' do
            control = ActiveRecord::QueryRecorder.new { add_epic([valid_reference]) }

            new_epics = Array.new(2) { create(:epic, group: group) }

            # threshold is 8 because
            # 1. we need to check hierarchy for each child epic (3 queries)
            # 2. we have to update the  record (2 including releasing savepoint)
            # 3. we have to update start and due dates for all updated epics
            # 4. we temporarily increased this from 6 due to
            #    https://gitlab.com/gitlab-org/gitlab/issues/11539
            expect do
              ActiveRecord::QueryRecorder.new { add_epic(new_epics.map { |epic| epic.to_reference(full: true) }) }
            end.not_to exceed_query_limit(control).with_threshold(8)
          end

          context 'when parent has inherited dates' do
            let_it_be(:epic_to_add) do
              create(:epic, group: group, start_date: 5.days.ago, due_date: 3.days.from_now)
            end

            let_it_be(:another_epic) do
              create(:epic, group: group, start_date: 3.days.ago, due_date: 5.days.from_now)
            end

            before do
              epic.update!(start_date: nil, due_date: nil, start_date_is_fixed: false, due_date_is_fixed: false)
            end

            it 'updates the parent dates' do
              expect { subject }.to change { epic.reload.children.count }.by(2)
                                .and change { epic.start_date }.from(nil).to(epic_to_add.start_date)
                                .and change { epic.due_date }.from(nil).to(another_epic.due_date)
                                .and change { epic.start_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                                .and change { epic.due_date_sourcing_epic_id }.from(nil).to(another_epic.id)
            end
          end
        end

        context 'when at least one epic is still not assigned to the parent epic' do
          before do
            epic_to_add.update!(parent: epic)
          end

          subject do
            add_epic(
              [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)]
            )
          end

          it 'creates new relationships' do
            expect { subject }.to change { epic.children.count }.from(1).to(2)

            expect(epic.reload.children).to match_array([epic_to_add, another_epic])
          end

          it 'creates system notes' do
            expect { subject }.to change { Note.system.count }.from(0).to(2)
          end

          it 'returns success status and created links', :aggregate_failures do
            expect(subject.keys).to match_array([:status, :created_references])
            expect(subject[:status]).to eq(:success)
            expect(subject[:created_references]).to match_array([another_epic])
          end
        end

        context 'when adding an Epic that has existing children' do
          context 'when Epic to add has more than 5 children' do
            subject { add_epic([valid_reference]) }

            before do
              create_list(:epic, 8, group: group, parent: epic_to_add)
            end

            include_examples 'returns success'
            include_examples 'system notes created'
          end
        end

        context 'when an epic is already assigned to another epic' do
          before do
            epic_to_add.update!(parent: another_epic)
          end

          subject { add_epic([valid_reference]) }

          it 'creates system notes' do
            expect { subject }.to change { Note.system.count }.from(0).to(3)
          end

          include_examples 'returns success'
        end
      end

      context 'when child and parent epics have a synced work item' do
        let_it_be(:parent_work_item) { create(:work_item, :epic, namespace: group) }
        let_it_be(:child_work_item) { create(:work_item, :epic, namespace: group) }
        let_it_be(:parent_epic) { create(:epic, group: group, issue_id: parent_work_item.id) }
        let_it_be(:child_epic) { create(:epic, group: group, issue_id: child_work_item.id, title: 'The child epic') }

        let(:synced_epic_param) { false }
        let(:params) { { issuable_references: [child_epic.to_reference], synced_epic: synced_epic_param } }

        subject(:create_link) { described_class.new(parent_epic, user, params).execute }

        before_all do
          group.add_reporter(user)
        end

        shared_examples 'rollback changes when creation fails' do
          context 'when work item link creation fails' do
            before do
              allow_next_instance_of(WorkItems::ParentLinks::CreateService) do |service|
                allow(service).to receive(:execute).and_return({ status: :error, message: 'error message' })
              end
            end

            it 'does not create relationships for the epic or the work item' do
              expect { create_link }.to not_change { parent_epic.children.count }
                .and(not_change { WorkItems::ParentLink.count })
            end

            it 'logs error' do
              allow(Gitlab::EpicWorkItemSync::Logger).to receive(:error).and_call_original
              expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error).with({
                child_id: child_epic.id,
                error_message: 'error message',
                group_id: group.id,
                message: 'Not able to set epic parent',
                parent_id: parent_epic.id
              })

              create_link
            end
          end

          context 'when epic link creation fails' do
            it 'does not create relationships for the epic or the work item' do
              allow_next_found_instance_of(::Epic) do |epic_instance|
                allow(epic_instance).to receive(:save).and_return(false)
              end

              expect { create_link }.to not_change { parent_epic.children.count }
                .and(not_change { WorkItems::ParentLink.count })
            end
          end

          context 'when updating relative_position fails' do
            it 'does not create relationships for the epic or the work item' do
              allow_next_instance_of(::WorkItems::ParentLink) do |parent_link_instance|
                allow(parent_link_instance).to receive(:update).and_return(false)
              end

              expect { create_link }.to not_change { parent_epic.children.count }
                .and(not_change { WorkItems::ParentLink.count })
            end
          end
        end

        it 'creates a new relationship for the epic and the synced work item' do
          expect { create_link }.to change { parent_epic.children.count }.by(1)
            .and(change { WorkItems::ParentLink.count }.by(1))

          expect(parent_epic.reload.children).to include(child_epic)
          expect(parent_work_item.reload.work_item_children).to include(child_work_item)
          expect(child_epic.reload.relative_position).to eq(child_work_item.parent_link.reload.relative_position)
        end

        it 'keeps epics timestamp in sync' do
          expect { create_link }.to change { parent_epic.children.count }.by(1)
            .and(change { WorkItems::ParentLink.count }.by(1))

          expect(parent_epic.reload.updated_at).to eq(parent_epic.work_item.updated_at)
          expect(child_epic.reload.updated_at).to eq(child_epic.work_item.updated_at)
        end

        it 'does not create resource event for the work item' do
          expect(WorkItems::ResourceLinkEvent).not_to receive(:create)

          expect { create_link }.to change { parent_epic.children.count }.by(1)
            .and(change { WorkItems::ParentLink.count }.by(1))
        end

        it 'creates system notes only for the epics' do
          expect { create_link }.to change { Note.system.count }.by(2)
          expect(parent_epic.notes.last.note).to eq("added epic #{child_epic.to_reference} as child epic")
          expect(child_epic.notes.last.note).to eq("added epic #{parent_epic.to_reference} as parent epic")
        end

        it_behaves_like 'rollback changes when creation fails'

        context 'with multiple children' do
          let_it_be(:child_work_item2) { create(:work_item, :epic, namespace: group) }
          let_it_be(:child_epic2) { create(:epic, group: group, issue_id: child_work_item2.id) }

          let(:params) { { issuable_references: [child_epic.to_reference, child_epic2.to_reference] } }

          it 'creates a new relationship for the epics and their synced work items' do
            expect { create_link }.to change { parent_epic.children.count }.by(2)
              .and(change { WorkItems::ParentLink.count }.by(2))

            expect(parent_epic.reload.children).to include(child_epic, child_epic2)
            expect(parent_work_item.reload.work_item_children).to include(child_work_item, child_work_item2)
            expect(child_epic.reload.relative_position).to eq(child_work_item.reload.parent_link.relative_position)
            expect(child_epic2.reload.relative_position).to eq(child_work_item2.reload.parent_link.relative_position)
          end

          it 'keeps epics timestamp in sync' do
            expect { create_link }.to change { parent_epic.children.count }.by(2)
              .and(change { WorkItems::ParentLink.count }.by(2))

            expect(parent_epic.reload.updated_at).to eq(parent_epic.work_item.updated_at)
            expect(child_epic.reload.updated_at).to eq(child_epic.work_item.updated_at)
            expect(child_epic2.reload.updated_at).to eq(child_epic2.work_item.updated_at)
          end

          it 'creates system notes only for the epics' do
            child_note_text = "added epic #{parent_epic.to_reference} as parent epic"
            expect { create_link }.to change { Note.system.count }.by(4)

            expect(child_epic.notes.last.note).to eq(child_note_text)
            expect(child_epic2.notes.last.note).to eq(child_note_text)
            expect(parent_epic.notes.last(2).pluck(:note)).to contain_exactly(
              "added epic #{child_epic.to_reference} as child epic",
              "added epic #{child_epic2.to_reference} as child epic"
            )
          end

          it_behaves_like 'rollback changes when creation fails'
        end

        context 'when synced_epic parameter is true' do
          let(:synced_epic_param) { true }

          it 'does not try to create a synced work item parent link' do
            expect(::WorkItems::ParentLinks::CreateService).not_to receive(:new)

            create_link
          end

          it 'does not create system notes' do
            expect(SystemNoteService).not_to receive(:change_epics_relation)
            expect(SystemNoteService).not_to receive(:move_child_epic_to_new_parent)

            create_link
          end

          it 'does not call Epics::UpdateDatesService' do
            expect(Epics::UpdateDatesService).not_to receive(:new)

            create_link
          end

          context 'when work_items_rolledup_dates feature flag is disabled' do
            before do
              allow(::Epics::UpdateDatesService).to receive(:new).and_call_original
              stub_feature_flags(work_items_rolledup_dates: false)
            end

            it 'calls Epics::UpdateDatesService' do
              expect(::Epics::UpdateDatesService).to receive(:new).with([parent_epic, child_epic])

              create_link
            end
          end
        end
      end
    end
  end
end
