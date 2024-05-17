# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicIssues::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:non_member) { create(:user) }
    let_it_be(:group, refind: true) { create(:group, :public, guests: guest) }
    let_it_be(:project, refind: true) do
      create(:project, :public, group: create(:group, :public), guests: guest)
    end

    let_it_be(:epic, reload: true) { create(:epic, group: group) }
    let_it_be(:issue, reload: true) { create(:issue, project: project) }
    let_it_be(:epic_issue, reload: true) { create(:epic_issue, epic: epic, issue: issue) }

    subject { described_class.new(epic_issue, user).execute }

    shared_examples 'removes relationship with the issue' do
      it 'returns success message' do
        is_expected.to eq(message: 'Relation was removed', status: :success)
      end

      it 'creates 2 system notes' do
        expect { subject }.to change { Note.count }.from(0).to(2)
      end

      it 'creates a note for epic correctly' do
        subject
        note = Note.find_by(noteable_id: epic.id, noteable_type: 'Epic')

        expect(note.note).to eq("removed issue #{issue.to_reference(epic.group)}")
        expect(note.author).to eq(user)
        expect(note.project).to be_nil
        expect(note.noteable_type).to eq('Epic')
        expect(note.system_note_metadata.action).to eq('epic_issue_removed')
      end

      it 'creates a note for issue correctly' do
        subject
        note = Note.find_by(noteable_id: issue.id, noteable_type: 'Issue')

        expect(note.note).to eq("removed from epic #{epic.to_reference(issue.project)}")
        expect(note.author).to eq(user)
        expect(note.project).to eq(issue.project)
        expect(note.noteable_type).to eq('Issue')
        expect(note.system_note_metadata.action).to eq('issue_removed_from_epic')
      end

      it 'counts an usage ping event' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_issue_removed)
          .with(author: user, namespace: group)

        subject
      end

      it 'triggers issuableEpicUpdated' do
        expect(GraphqlTriggers).to receive(:issuable_epic_updated).with(issue)

        subject
      end

      context 'refresh epic dates' do
        it 'calls UpdateDatesService' do
          expect(Epics::UpdateDatesService).to receive(:new).with([epic_issue.epic]).and_call_original

          subject
        end
      end
    end

    context 'when epics feature is disabled' do
      let(:user) { guest }

      it 'returns an error' do
        is_expected.to eq(message: 'No Issue Link found', status: :error, http_status: 404)
      end

      it 'does not trigger issuableEpicUpdated' do
        expect(GraphqlTriggers).not_to receive(:issuable_epic_updated)

        subject
      end
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
        allow(Epics::UpdateDatesService).to receive(:new).and_call_original
      end

      context 'when user has permissions to remove associations' do
        let(:user) { guest }

        it 'removes related issue' do
          expect { subject }.to change { EpicIssue.count }.from(1).to(0)
        end

        it_behaves_like 'removes relationship with the issue'

        context 'when epic has inherited dates' do
          let_it_be(:milestone) do
            create(:project_milestone, project: project, start_date: 1.day.ago, due_date: 1.day.from_now)
          end

          let_it_be(:epic_with_dates) do
            create(
              :epic,
              group: group,
              start_date: milestone.start_date,
              due_date: milestone.due_date,
              title: "lalala",
              start_date_is_fixed: false,
              due_date_is_fixed: false,
              start_date_sourcing_milestone_id: milestone.id,
              due_date_sourcing_milestone_id: milestone.id
            )
          end

          it 'removes relationship and updates epic dates' do
            epic_issue_link =
              create(:epic_issue, epic: epic_with_dates, issue: create(:issue, project: project, milestone: milestone))

            expect(Epics::UpdateDatesService).to receive(:new).with([epic_with_dates])

            expect { described_class.new(epic_issue_link, user).execute }
              .to change { EpicIssue.count }.by(-1)
              .and change { epic_with_dates.reload.start_date }.from(milestone.start_date).to(nil)
              .and change { epic_with_dates.due_date }.from(milestone.due_date).to(nil)
              .and change { epic_with_dates.start_date_sourcing_milestone_id }.from(milestone.id).to(nil)
              .and change { epic_with_dates.due_date_sourcing_milestone_id }.from(milestone.id).to(nil)
          end
        end

        context 'when epic has a synced work item' do
          let_it_be(:child_issue, reload: true) { create(:issue, project: project) }
          let_it_be(:epic, reload: true) { create(:epic, :with_synced_work_item, group: group) }
          let_it_be(:epic_issue, refind: true) { create(:epic_issue, epic: epic, issue: child_issue) }
          let_it_be(:work_item_issue) { WorkItem.find(child_issue.id) }

          before do
            create(:parent_link, work_item_parent_id: epic.issue_id, work_item_id: child_issue.id)
            allow(GraphqlTriggers).to receive(:issuable_epic_updated).and_call_original
          end

          it 'removes the epic and work item link and keep epic in sync' do
            expect { subject }.to change { EpicIssue.count }.by(-1)
              .and(change { WorkItems::ParentLink.count }.by(-1))

            expect(epic.reload.updated_at).to eq(epic.work_item.updated_at)
          end

          it_behaves_like 'removes relationship with the issue' do
            let(:issue) { child_issue }
          end

          context 'when destroying work item parent link fails' do
            before do
              allow_next_instance_of(::WorkItems::ParentLinks::DestroyService) do |service|
                allow(service).to receive(:execute).and_return({ status: :error, message: 'error message' })
              end
            end

            it 'does not remove parent epic or destroy work item parent link' do
              expect { subject }.to not_change { EpicIssue.count }
                .and(not_change { WorkItems::ParentLink.count })

              expect(epic.reload.issues).to include(child_issue)
              expect(epic.work_item.reload.work_item_children).to include(work_item_issue)
              expect(GraphqlTriggers).not_to have_received(:issuable_epic_updated)
              expect(::Epics::UpdateDatesService).not_to have_received(:new)
            end

            it 'logs error' do
              allow(Gitlab::EpicWorkItemSync::Logger).to receive(:error).and_call_original
              expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error).with({
                error_message: 'error message',
                group_id: group.id,
                message: 'Not able to destroy work item links',
                epic_id: epic.id,
                issue_id: child_issue.id
              })

              subject
            end
          end

          context 'when destroying epic issue link fails' do
            before do
              allow(epic_issue).to receive(:destroy!)
                .and_raise(ActiveRecord::RecordNotDestroyed.new(epic_issue), 'error message')
            end

            it 'raises an error and does not remove relationships' do
              expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed)
                .and(not_change { EpicIssue.count })
                .and(not_change { WorkItems::ParentLink.count })

              expect(epic.reload.issues).to include(child_issue)
              expect(epic.work_item.reload.work_item_children).to include(work_item_issue)
              expect(GraphqlTriggers).not_to have_received(:issuable_epic_updated)
              expect(Epics::UpdateDatesService).not_to have_received(:new)
            end
          end

          context 'when synced_epic argument is true' do
            subject(:destroy_link) { described_class.new(epic_issue, user, synced_epic: true).execute }

            it 'does not call WorkItems::ParentLinks::DestroyService nor create notes' do
              expect(::WorkItems::ParentLinks::DestroyService).not_to receive(:new)

              expect { destroy_link }
                .to change { EpicIssue.count }.by(-1)
                .and(not_change { WorkItems::ParentLink.count })
                .and(not_change { Note.count })
            end

            it 'does not call Epics::UpdateDatesService' do
              expect(Epics::UpdateDatesService).not_to receive(:new)

              destroy_link
            end

            context 'when work_items_rolledup_dates feature flag is disabled' do
              before do
                stub_feature_flags(work_items_rolledup_dates: false)
              end

              it 'calls Epics::UpdateDatesService' do
                expect(Epics::UpdateDatesService).to receive(:new).with([epic])

                destroy_link
              end
            end
          end
        end

        context 'when epic_relations_for_non_members feature flag is disabled' do
          let(:user) { non_member }

          before do
            stub_feature_flags(epic_relations_for_non_members: false)
            group.add_guest(non_member)
          end

          it 'returns success message when user is a guest in the epic group' do
            is_expected.to eq(message: 'Relation was removed', status: :success)
          end
        end
      end

      context 'user does not have permissions to remove associations' do
        let(:user) { non_member }

        it 'does not remove relation' do
          expect { subject }.not_to change { EpicIssue.count }.from(1)
        end

        it 'returns error message' do
          is_expected.to eq(message: 'No Issue Link found', status: :error, http_status: 404)
        end

        it 'does not counts an usage ping event' do
          expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_issue_removed)

          subject
        end

        it 'does not trigger issuableEpicUpdated' do
          expect(GraphqlTriggers).not_to receive(:issuable_epic_updated)

          subject
        end
      end
    end
  end
end
