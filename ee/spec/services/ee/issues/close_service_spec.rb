# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::CloseService, feature_category: :team_planning do
  describe '#execute' do
    context 'when project bot it logs audit events' do
      let(:service) { described_class.new(container: project, current_user: project_bot) }
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }

      before do
        project.add_maintainer(project_bot)
      end

      include_examples 'audit event logging' do
        let(:issue) { create(:issue, title: "My issue", project: project, author: project_bot) }
        let(:operation) { service.execute(issue) }
        let(:event_type) { 'issue_closed_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: issue.project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: "issue_closed_by_project_bot",
              target_id: issue.id,
              target_type: 'Issue',
              target_details: {
                iid: issue.iid,
                id: issue.id
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Closed issue #{issue.title}"
            }
          }
        end
      end
    end

    context 'when is epic work item' do
      let_it_be(:current_user) { create(:user) }
      let(:service) { described_class.new(container: group, current_user: current_user) }
      let_it_be(:group) { create(:group) }

      let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:epic) { work_item.synced_epic }

      subject(:execute) { service.execute(work_item) }

      before_all do
        group.add_developer(current_user)
      end

      before do
        stub_feature_flags(synced_epic_work_item_editable: true)
      end

      it_behaves_like 'syncs all data from an epic to a work item'

      it 'syncs the state to the epic' do
        expect { execute }.to change { epic.reload.state }.from('opened').to('closed')
          .and change { work_item.reload.state }.from('opened').to('closed')

        expect(work_item.closed_by).to eq(epic.closed_by)
        expect(work_item.closed_at).to eq(epic.closed_at)
      end

      it 'publishes a work item updated event' do
        expect { execute }
          .to publish_event(::WorkItems::WorkItemUpdatedEvent)
          .with({
            id: work_item.id,
            namespace_id: work_item.namespace.id
          })
      end

      context 'when epic and work item was already closed' do
        before do
          epic.close!
          work_item.close!
        end

        it 'does not change the state' do
          expect { execute }.to not_change { epic.reload.state }
            .and not_change { work_item.reload.state }
        end
      end

      context 'when the epic is already closed' do
        before do
          epic.close!
          epic.update!(closed_by: create(:user), closed_at: Time.current - 1.day)
          stub_feature_flags(synced_epic_work_item_editable: true)
        end

        it 'does not error and syncs closed_at and closed_by' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.state).to eq('closed')
          expect(epic.reload.state).to eq('closed')
          expect(work_item.closed_at).to eq(epic.closed_at)
          expect(work_item.closed_by).to eq(epic.closed_by)
        end
      end

      context 'when closing the epic fails due an other error' do
        before do
          stub_feature_flags(synced_epic_work_item_editable: true)
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:close!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'rolls back updating the work_item, logs error and raises it' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync closing epic work item",
              error_message: 'Record invalid',
              work_item_id: work_item.id
            })

          expect(Gitlab::ErrorTracking)
            .to receive(:track_and_raise_exception)
                  .with(an_instance_of(ActiveRecord::RecordInvalid), { work_item_id: work_item.id })
                  .and_call_original

          expect { execute }.to raise_error(ActiveRecord::RecordInvalid)

          expect(work_item.reload.state).to eq('opened')
          expect(epic.reload.state).to eq('opened')
        end
      end

      context 'when it has no legacy epic' do
        let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'closes the work item' do
          execute

          expect(work_item.reload.state).to eq('closed')
        end
      end
    end
  end
end
