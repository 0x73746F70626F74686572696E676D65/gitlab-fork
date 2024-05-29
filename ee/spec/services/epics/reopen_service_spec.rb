# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Epics::ReopenService, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group, :internal) }
  let_it_be(:user) { create(:user) }
  let_it_be(:epic, reload: true) { create(:epic, group: group, state: :closed, closed_at: Date.today, closed_by: user) }

  describe '#execute' do
    subject { described_class.new(group: group, current_user: user) }

    context 'when epics are disabled' do
      before do
        group.add_maintainer(user)
      end

      it 'does not reopen the epic' do
        expect { subject.execute(epic) }.not_to change { epic.state }
      end
    end

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when a user has permissions to update the epic' do
        before_all do
          group.add_maintainer(user)
        end

        context 'when reopening a closed epic' do
          it 'reopens the epic' do
            expect { subject.execute(epic) }.to change { epic.state }.from('closed').to('opened')
          end

          it 'publishes an EpicUpdated event' do
            expect { subject.execute(epic) }
              .to publish_event(Epics::EpicUpdatedEvent)
              .with({ id: epic.id, group_id: group.id })
          end

          it 'removes closed_by' do
            expect { subject.execute(epic) }.to change { epic.closed_by }.to(nil)
          end

          it 'removes closed_at' do
            expect { subject.execute(epic) }.to change { epic.closed_at }.to(nil)
          end

          it 'creates a resource state event' do
            expect { subject.execute(epic) }.to change { epic.resource_state_events.count }.by(1)

            event = epic.resource_state_events.last

            expect(event.state).to eq('opened')
          end

          it 'notifies the subscribers' do
            notification_service = double

            expect(NotificationService).to receive(:new).and_return(notification_service)
            expect(notification_service).to receive(:reopen_epic).with(epic, user)

            subject.execute(epic)
          end

          it 'creates new event' do
            expect { subject.execute(epic) }.to change { Event.count }
          end

          it 'tracks reopening the epic' do
            expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter)
              .to receive(:track_epic_reopened_action).with(author: user, namespace: group)

            subject.execute(epic)
          end

          context 'with a synced work item' do
            let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group, state: :closed) }
            let(:work_item) { epic.work_item }

            subject { described_class.new(group: group, current_user: user).execute(epic) }

            it_behaves_like 'syncs all data from an epic to a work item'

            it 'syncs the state to the work item' do
              expect { subject }.to change { epic.state }.from('closed').to('opened')
                .and change { work_item.reload.state }.from('closed').to('opened')

              expect(work_item.closed_by).to eq(epic.closed_by)
              expect(work_item.closed_at).to eq(epic.closed_at)
            end

            context 'when epic and work item was already opened' do
              before do
                epic.update!(state: :opened)
                work_item.update!(state: :opened)
              end

              it 'does not change the state' do
                expect { subject }.to not_change { epic.reload.state }
                  .and not_change { work_item.reload.state }
              end
            end

            context 'when re-opening the work item fails' do
              before do
                work_item.update!(state: :opened)
              end

              it 'rolls back updating the epic' do
                subject

                expect(epic.reload.state).to eq('closed')
              end
            end
          end

          context 'when project bot it logs audit events' do
            let_it_be(:user) { create(:user, :project_bot, email: "bot@example.com") }

            before_all do
              group.add_maintainer(user)
            end

            include_examples 'audit event logging' do
              let(:licensed_features_to_stub) { { epics: true } }
              let(:operation) { subject.execute(epic) }
              let(:event_type) { 'epic_reopened_by_project_bot' }
              let(:fail_condition!) { expect(user).to receive(:project_bot?).and_return(false) }
              let(:attributes) do
                {
                  author_id: user.id,
                  entity_id: epic.group.id,
                  entity_type: 'Group',
                  details: {
                    author_name: user.name,
                    event_name: "epic_reopened_by_project_bot",
                    target_id: epic.id,
                    target_type: 'Epic',
                    target_details: {
                      iid: epic.iid,
                      id: epic.id
                    }.to_s,
                    author_class: user.class.name,
                    custom_message: "Reopened epic #{epic.title}"
                  }
                }
              end
            end
          end
        end

        context 'when trying to reopen an opened epic' do
          before do
            epic.update!(state: :opened)
          end

          it 'does not change the epic state' do
            expect { subject.execute(epic) }.not_to change { epic.state }
          end

          it 'does not change closed_at' do
            expect { subject.execute(epic) }.not_to change { epic.closed_at }
          end

          it 'does not change closed_by' do
            expect { subject.execute(epic) }.not_to change { epic.closed_by }
          end

          it 'does not create a resource state event' do
            expect { subject.execute(epic) }.not_to change { epic.resource_state_events.count }
          end

          it 'does not send any emails' do
            expect(NotificationService).not_to receive(:new)

            subject.execute(epic)
          end

          it 'does not create an event' do
            expect { subject.execute(epic) }.not_to change { Event.count }
          end

          it 'does not track reopening the epic' do
            expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_reopened_action)

            subject.execute(epic)
          end
        end
      end

      context 'when a user does not have permissions to update epic' do
        it 'does not reopen the epic' do
          expect { subject.execute(epic) }.not_to change { epic.state }
        end
      end
    end
  end
end
