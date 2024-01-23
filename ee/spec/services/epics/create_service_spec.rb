# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::CreateService, feature_category: :portfolio_management do
  let_it_be(:ancestor_group) { create(:group, :internal) }
  let_it_be(:group) { create(:group, :internal, parent: ancestor_group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:label1) { create(:group_label, group: group, title: 'priority::1', color: '#FF0000') }
  let_it_be(:label2) { create(:group_label, group: group, title: 'priority::4', color: '#CC1111') }
  let_it_be(:synced_parent_work_item) { create(:work_item, :epic, namespace: group) }
  let_it_be(:parent_epic) { create(:epic, group: group, issue_id: synced_parent_work_item.id) }
  let(:base_attrs) do
    %i[title description confidential updated_by_id last_edited_by_id last_edited_at closed_by_id closed_at]
  end

  let(:params) do
    {
      title: 'new epic',
      description: 'epic description',
      parent_id: parent_epic.id,
      confidential: true,
      add_label_ids: [label1.id],
      label_ids: [label2.id],
      remove_label_ids: [label1.id],
      author: author,
      updated_by_id: user.id,
      last_edited_by_id: other_user.id,
      last_edited_at: '2024-01-10T01:00:00Z',
      closed_by_id: other_user.id,
      closed_at: '2024-01-11T01:00:00Z',
      state_id: 2
    }
  end

  subject { described_class.new(group: group, current_user: user, params: params).execute }

  before do
    group.add_reporter(user)
    stub_licensed_features(epics: true, subepics: true)
  end

  it_behaves_like 'rate limited service' do
    let(:key) { :issues_create }
    let(:key_scope) { %i[current_user] }
    let(:application_limit_key) { :issues_create_limit }
    let(:created_model) { Epic }
    let(:service) { described_class.new(group: group, current_user: user, params: params) }
  end

  describe '#execute' do
    it 'creates one epic correctly' do
      allow(NewEpicWorker).to receive(:perform_async)

      expect { subject }.to change { Epic.count }.by(1)

      epic = Epic.last
      expect(epic).to be_persisted
      expect(epic.attributes.with_indifferent_access.values_at(*base_attrs)).to eq(params.values_at(*base_attrs))
      expect(epic.state_id).to eq(Epic.available_states['closed'])
      expect(epic.author).to eq(author)
      expect(epic.parent).to eq(parent_epic)
      expect(epic.labels).to contain_exactly(label2)
      expect(epic.relative_position).not_to be_nil
      expect(epic.confidential).to be_truthy
      expect(NewEpicWorker).to have_received(:perform_async).with(epic.id, user.id)
    end

    context 'when syncing work item' do
      it 'creates an epic work item' do
        expect { subject }.to change { Epic.count }.by(1).and(change { WorkItem.count }.by(1))
      end

      it 'creates epic work item with same attributes' do
        subject

        epic = Epic.last
        work_item = WorkItem.last

        expect(work_item.work_item_type.name).to eq('Epic')
        expect(epic.attributes.with_indifferent_access.slice(*base_attrs))
          .to eq(work_item.attributes.with_indifferent_access.slice(*base_attrs))

        expect(epic.issue_id).to eq(work_item.id)
        expect(epic.iid).to eq(work_item.iid)
        expect(epic.created_at).to eq(work_item.created_at)
        expect(epic.author).to eq(work_item.author)
        expect(epic.parent.work_item).to eq(work_item.work_item_parent)
        expect(epic.labels).to eq(work_item.labels)
        expect(epic.state).to eq(work_item.state)
      end

      context 'when work item creation fails' do
        it 'does not create epic' do
          error_msg = 'error 1, error 2'
          allow_next_instance_of(Epics::CreateService) do |instance|
            allow(instance).to receive(:create_work_item_for).and_return(
              instance_double(
                ServiceResponse,
                success?: false,
                payload: { errors: instance_double(ActiveModel::Errors, full_messages: error_msg.split(", ")) })
            )
          end

          expect(Gitlab::AppLogger).to receive(:error)
                                   .with("Unable create synced work item: #{error_msg}. Group ID: #{group.id}")
          expect { subject }.to raise_error(StandardError, error_msg).and not_change { Epic.count }
        end
      end

      context 'when epic creation fails' do
        it 'does not create work item' do
          allow_next_instance_of(Epic) do |instance|
            allow(instance).to receive(:save).and_return(false)
          end

          expect { subject }.to not_change { Epic.count }.and(not_change { WorkItem.count })
        end
      end

      context 'when epic_creation_with_synced_work_item feature flag is disabled' do
        before do
          stub_feature_flags(epic_creation_with_synced_work_item: false)
        end

        it 'does not create epic work item' do
          expect { subject }.to change { Epic.count }.by(1).and(not_change { WorkItem.count })
        end
      end
    end

    context 'handling parent change' do
      context 'when parent is set' do
        it 'creates system notes' do
          subject

          epic = Epic.last
          expect(epic.parent).to eq(parent_epic)
          expect(epic.notes.last.note).to eq("added epic #{parent_epic.to_reference} as parent epic")
          expect(parent_epic.notes.last.note).to eq("added epic #{epic.to_reference} as child epic")
        end
      end

      context 'when parent is not set' do
        it 'does not create system notes' do
          params[:parent_id] = nil
          subject

          epic = Epic.last
          expect(epic.parent).to be_nil
          expect(epic.notes).to be_empty
        end
      end

      context 'when user has not access to parent epic' do
        let_it_be(:external_epic) { create(:epic, group: create(:group, :private)) }

        shared_examples 'creates epic without parent' do
          it 'does not set parent' do
            subject

            epic = Epic.last
            expect(epic.parent).to be_nil
            expect(epic.notes).to be_empty
          end
        end

        context 'when parent_id param is set' do
          let(:params) { { title: 'new epic', parent_id: external_epic.id } }

          it_behaves_like 'creates epic without parent'
        end

        context 'when parent param is set' do
          let(:params) { { title: 'new epic', parent: external_epic } }

          it_behaves_like 'creates epic without parent'
        end

        context 'when both parent and parent_id params are set' do
          let(:params) { { title: 'new epic', parent: external_epic, parent_id: external_epic.id } }

          it_behaves_like 'creates epic without parent'
        end
      end
    end

    context 'handling fixed dates' do
      it 'sets the fixed date correctly' do
        date = Date.new(2019, 10, 10)
        params[:start_date_fixed] = date
        params[:start_date_is_fixed] = true

        subject

        epic = Epic.last
        expect(epic.start_date).to eq(date)
        expect(epic.start_date_fixed).to eq(date)
        expect(epic.start_date_is_fixed).to be_truthy
      end
    end

    context 'after_save callback to store_mentions' do
      let(:labels) { create_pair(:group_label, group: group) }

      context 'when mentionable attributes change' do
        context 'when content has no mentions' do
          let(:params) { { title: 'Title', description: "Description with no mentions" } }

          it 'calls store_mentions! and saves no mentions' do
            expect_next_instance_of(Epic) do |instance|
              expect(instance).to receive(:store_mentions!).and_call_original
            end

            expect { subject }.not_to change { EpicUserMention.count }
          end
        end

        context 'when content has mentions' do
          let(:params) { { title: 'Title', description: "Description with #{user.to_reference}" } }

          it 'calls store_mentions! and saves mentions' do
            expect_next_instance_of(Epic) do |instance|
              expect(instance).to receive(:store_mentions!).and_call_original
            end

            expect { subject }.to change { EpicUserMention.count }.by(1)
          end
        end

        context 'when mentionable.save fails' do
          let(:params) { { title: '', label_ids: labels.map(&:id) } }

          it 'does not call store_mentions and saves no mentions' do
            expect_next_instance_of(Epic) do |instance|
              expect(instance).not_to receive(:store_mentions!).and_call_original
            end

            expect { subject }.not_to change { EpicUserMention.count }
            expect(subject.valid?).to be false
          end
        end

        context 'when description param has quick action' do
          context 'for /parent_epic' do
            shared_examples 'assigning a valid parent epic' do
              it 'sets parent epic' do
                parent = create(:epic, group: new_group)
                description = "/parent_epic #{parent.to_reference(new_group, full: true)}"
                params = { title: 'New epic with parent', description: description }

                epic = described_class.new(group: group, current_user: user, params: params).execute

                expect(epic.reset.parent).to eq(parent)
              end
            end

            shared_examples 'assigning an invalid parent epic' do
              it 'does not set parent epic' do
                parent = create(:epic, group: new_group)
                description = "/parent_epic #{parent.to_reference(new_group, full: true)}"
                params = { title: 'New epic with parent', description: description }

                epic = described_class.new(group: group, current_user: user, params: params).execute

                expect(epic.reset.parent).to eq(nil)
              end
            end

            context 'when parent is in the same group' do
              let(:new_group) { group }

              it_behaves_like 'assigning a valid parent epic'
            end

            context 'when parent is in an ancestor group' do
              let(:new_group) { ancestor_group }

              before do
                ancestor_group.add_reporter(user)
              end

              it_behaves_like 'assigning a valid parent epic'
            end

            context 'when parent is in a descendant group' do
              let_it_be(:descendant_group) { create(:group, :private, parent: group) }
              let(:new_group) { descendant_group }

              before do
                descendant_group.add_reporter(user)
              end

              it_behaves_like 'assigning a valid parent epic'
            end

            context 'when parent is in a different group hierarchy' do
              let_it_be(:other_group) { create(:group, :private) }
              let(:new_group) { other_group }

              context 'when user has access to the group' do
                before do
                  other_group.add_reporter(user)
                end

                it_behaves_like 'assigning a valid parent epic'
              end

              context 'when user does not have access to the group' do
                it_behaves_like 'assigning an invalid parent epic'
              end
            end
          end

          context 'for /child_epic' do
            it 'sets a child epic' do
              child_epic = create(:epic, group: group)
              description = "/child_epic #{child_epic.to_reference}"
              params = { title: 'New epic with child', description: description }

              epic = described_class.new(group: group, current_user: user, params: params).execute

              expect(epic.reload.children).to include(child_epic)
            end

            context 'when child epic cannot be assigned' do
              it 'does not set child epic' do
                other_group = create(:group, :private)
                child_epic = create(:epic, group: other_group)
                description = "/child_epic #{child_epic.to_reference(group)}"
                params = { title: 'New epic with child', description: description }

                epic = described_class.new(group: group, current_user: user, params: params).execute

                expect(epic.reload.children).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
