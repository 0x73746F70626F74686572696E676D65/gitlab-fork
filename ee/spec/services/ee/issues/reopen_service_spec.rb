# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::ReopenService, feature_category: :team_planning do
  describe '#execute' do
    context 'when project bot it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:project) { create(:project, :repository) }

      before do
        project.add_maintainer(project_bot)
      end

      include_examples 'audit event logging' do
        let(:issue) { create(:issue, :closed, title: "My issue", project: project, author: project_bot) }
        let(:operation) { service.execute(issue) }
        let(:event_type) { 'issue_reopened_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: issue.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'issue_reopened_by_project_bot',
              target_id: issue.id,
              target_type: 'Issue',
              target_details: {
                iid: issue.iid,
                id: issue.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Reopened issue #{issue.title}"
            }
          }
        end
      end
    end

    context 'when is epic work item' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:group) { create(:group) }

      let_it_be_with_reload(:work_item) { create(:work_item, :closed, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:epic) { work_item.synced_epic }
      let(:service) { described_class.new(container: group, current_user: current_user) }

      subject(:execute) { service.execute(work_item) }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_feature_flags(synced_epic_work_item_editable: true)
      end

      it_behaves_like 'syncs all data from an epic to a work item'

      it 'syncs the state to the epic' do
        expect { execute }.to change { epic.reload.state }.from('closed').to('opened')
          .and change { work_item.reload.state }.from('closed').to('opened')

        expect(work_item.closed_by).to be_nil
        expect(work_item.closed_at).to be_nil
      end

      it 'publishes a work item updated event' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemUpdatedEvent)
          .with({
            id: work_item.id,
            namespace_id: work_item.namespace.id
          })
      end

      context 'when epic and work item was already opened' do
        before do
          epic.reopen!
          work_item.reopen!
        end

        it 'does not change the state' do
          expect { execute }.to not_change { epic.reload.state }
            .and not_change { work_item.reload.state }
        end
      end

      context 'when the epic is already open' do
        before do
          epic.reopen!
        end

        it 'does not error and changes both to open' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.state).to eq('opened')
          expect(epic.reload.state).to eq('opened')
        end
      end

      context 'when reopening the epic fails due to an error' do
        before do
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:reopen!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'rolls back updating the work_item, logs error and raises it' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync reopening epic work item",
              error_message: 'Record invalid',
              work_item_id: work_item.id
            })

          expect(Gitlab::ErrorTracking)
            .to receive(:track_and_raise_exception)
                  .with(an_instance_of(ActiveRecord::RecordInvalid), { work_item_id: work_item.id })
                  .and_call_original

          expect { execute }.to raise_error(ActiveRecord::RecordInvalid)

          expect(work_item.reload.state).to eq('closed')
          expect(epic.reload.state).to eq('closed')
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(sync_work_item_to_epic: false, synced_epic_work_item_editable: true)
        end

        it 'does not change the epic' do
          execute

          expect(work_item.reload.state).to eq('opened')
          expect(epic.reload.state).to eq('closed')
        end
      end
    end
  end
end
