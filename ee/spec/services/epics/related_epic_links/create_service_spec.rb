# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::RelatedEpicLinks::CreateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create :group }
    let_it_be(:issuable) { create :epic, group: group }
    let_it_be(:issuable2) { create :epic, group: group }
    let_it_be(:restricted_issuable) { create(:epic, group: create(:group, :private)) }
    let_it_be(:another_group) { create :group }
    let_it_be(:issuable3) { create :epic, group: another_group }
    let_it_be(:issuable_a) { create :epic, group: group }
    let_it_be(:issuable_b) { create :epic, group: group }
    let_it_be(:issuable_link) { create :related_epic_link, source: issuable, target: issuable_b, link_type: IssuableLink::TYPE_RELATES_TO }

    let(:issuable_parent) { issuable.group }
    let(:issuable_type) { :epic }
    let(:issuable_link_class) { Epic::RelatedEpicLink }
    let(:params) { {} }

    before do
      stub_licensed_features(epics: true, related_epics: true)
      group.add_guest(user)
      another_group.add_guest(user)
    end

    it_behaves_like 'issuable link creation'
    it_behaves_like 'issuable link creation with blocking link_type' do
      let(:params) do
        { issuable_references: [issuable2.to_reference, issuable3.to_reference(issuable3.group, full: true)] }
      end
    end

    context 'with permission checks' do
      let_it_be(:other_user) { create(:user) }

      let(:error_msg) { "Couldn't link epics. You must have at least the Guest role in the epic's group." }
      let(:params) { { issuable_references: [issuable3.to_reference(full: true)] } }

      subject { described_class.new(issuable, current_user, params).execute }

      shared_examples 'creates link' do
        it 'creates relationship', :aggregate_failures do
          expect { subject }.to change(issuable_link_class, :count).by(1)

          expect(issuable_link_class.find_by!(target: issuable3))
            .to have_attributes(source: issuable, link_type: 'relates_to')
        end
      end

      shared_examples 'fails to create link' do
        it 'does not create relationship', :aggregate_failures do
          expect { subject }.not_to change { issuable_link_class.count }
          is_expected.to eq(message: error_msg, status: :error, http_status: 403)
        end
      end

      context 'when user is not a guest in source group' do
        let_it_be(:current_user) { create(:user, guest_of: another_group) }

        it_behaves_like 'fails to create link'
      end

      context 'when user is not a guest in target group' do
        let_it_be(:current_user) { create(:user, guest_of: group) }

        it_behaves_like 'creates link'
      end

      context 'when related_epics feature is not available' do
        let(:current_user) { user }

        context 'for source group' do
          before do
            stub_licensed_features(epics: true, related_epics: false)
            allow(another_group).to receive(:licensed_feature_available?).with(anything).and_call_original
            allow(another_group).to receive(:licensed_feature_available?).with(:related_epics).and_return(true)
          end

          it_behaves_like 'fails to create link'
        end

        context 'for target group' do
          before do
            stub_licensed_features(epics: true, related_epics: false)
            allow(group).to receive(:licensed_feature_available?).with(anything).and_call_original
            allow(group).to receive(:licensed_feature_available?).with(:related_epics).and_return(true)
          end

          it_behaves_like 'creates link'
        end
      end
    end

    context 'for synced epic work items' do
      let(:current_user) { user }
      let(:params) { { issuable_references: [epic_b.to_reference(full: true)] } }
      let_it_be_with_reload(:epic_a) { create(:epic, :without_synced_work_item, group: group) }
      let_it_be_with_reload(:epic_b) { create(:epic, :without_synced_work_item, group: group) }

      subject(:execute) { described_class.new(epic_a, current_user, params).execute }

      shared_examples 'only creates an epic link' do
        it 'creates an epic link but no work item link' do
          expect { execute }.to change { Epic::RelatedEpicLink.count }.by(1)
            .and not_change { WorkItems::RelatedWorkItemLink.count }
        end
      end

      context 'when no epic has a synced work item' do
        it_behaves_like 'only creates an epic link'
      end

      context 'when source has a synced epic work item' do
        let_it_be_with_reload(:epic_a) { create(:epic, :with_synced_work_item, group: group) }

        it_behaves_like 'only creates an epic link'
      end

      context 'when target has a synced epic work item' do
        let_it_be_with_reload(:epic_b) { create(:epic, :with_synced_work_item, group: group) }

        it_behaves_like 'only creates an epic link'
      end

      context 'when both source and target have a synced epic work item' do
        let_it_be(:epic_a) { create(:epic, :with_synced_work_item, group: group) }
        let_it_be(:epic_b) { create(:epic, :with_synced_work_item, group: group) }

        it_behaves_like 'syncs all data from an epic to a work item' do
          let(:epic) { epic_a }
        end

        it 'creates a link for the epics and the synced work item' do
          expect { execute }.to change { Epic::RelatedEpicLink.count }.by(1)
            .and change { WorkItems::RelatedWorkItemLink.count }.by(1)

          expect(WorkItems::RelatedWorkItemLink.find_by!(target: epic_b.work_item))
            .to have_attributes(source: epic_a.work_item, link_type: IssuableLink::TYPE_RELATES_TO)

          expect(epic_a.reload.updated_at).to eq(epic_a.work_item.updated_at)
          expect(epic_b.reload.updated_at).to eq(epic_b.work_item.updated_at)
        end

        context 'when synced_epic parameter is true' do
          let(:params) { { issuable_references: [epic_b.to_reference(full: true)], link_type: IssuableLink::TYPE_BLOCKS, synced_epic: true } }

          it 'does not try to create a synced work item link' do
            expect(WorkItems::RelatedWorkItemLinks::CreateService).not_to receive(:new)

            execute
          end

          it 'bypasses permission checks' do
            new_user = create(:user)
            service = described_class.new(epic_a, new_user, params)

            expect { service.execute }.to change { Epic::RelatedEpicLink.count }.by(1)
              .and not_change { WorkItems::RelatedWorkItemLink.count }
          end
        end

        context 'when link type is blocking' do
          let(:params) { { issuable_references: [epic_b.to_reference(full: true)], link_type: IssuableLink::TYPE_BLOCKS } }

          it 'creates a blocking link' do
            execute

            expect(WorkItems::RelatedWorkItemLink.find_by!(target: epic_b.work_item))
              .to have_attributes(source: epic_a.work_item, link_type: IssuableLink::TYPE_BLOCKS)
          end
        end

        context 'when link type is blocked by' do
          let(:params) { { issuable_references: [epic_b.to_reference(full: true)], link_type: IssuableLink::TYPE_IS_BLOCKED_BY } }

          it 'creates a blocking link' do
            execute

            expect(WorkItems::RelatedWorkItemLink.find_by!(target: epic_a.work_item))
              .to have_attributes(source: epic_b.work_item, link_type: IssuableLink::TYPE_BLOCKS)
          end
        end

        context 'when multiple epics are referenced' do
          let_it_be(:epic_c) { create(:epic, :with_synced_work_item, group: group) }

          let(:params) { { issuable_references: [epic_b.to_reference(full: true), epic_c.to_reference(full: true)] } }

          it 'creates a link for the epics and the synced work item' do
            expect { execute }.to change { Epic::RelatedEpicLink.count }.by(2)
              .and change { WorkItems::RelatedWorkItemLink.count }.by(2)

            expect(WorkItems::RelatedWorkItemLink.where(source: epic_a.work_item)).to include(
              an_object_having_attributes(target: epic_b.work_item, link_type: IssuableLink::TYPE_RELATES_TO),
              an_object_having_attributes(target: epic_c.work_item, link_type: IssuableLink::TYPE_RELATES_TO)
            )
          end

          context 'when epic does not have a synced work item' do
            let_it_be(:epic_c) { create(:epic, :without_synced_work_item, group: group) }

            it 'does create related work item links for the rest' do
              expect { execute }.to change { Epic::RelatedEpicLink.count }.by(2)
                .and change { WorkItems::RelatedWorkItemLink.count }.by(1)
            end
          end
        end

        context 'when creating related work item links fails' do
          before do
            allow_next_instance_of(WorkItems::RelatedWorkItemLinks::CreateService) do |instance|
              allow(instance).to receive(:execute).and_return({ status: :error, message: "Some error" })
            end
          end

          it 'does not create an epic link nor a work item link' do
            expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
              .with({
                message: "Not able to create work item links",
                error_message: "Some error",
                group_id: group.id,
                epic_id: epic_a.id
              })

            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError),
              { epic_id: epic_a.id }
            )

            expect { execute }.to not_change { Epic::RelatedEpicLink.count }
              .and not_change { WorkItems::RelatedWorkItemLink.count }
          end

          it 'returns an error' do
            expect(execute)
              .to eq({ status: :error, message: "Couldn't create link due to an internal error.", http_status: 422 })
          end
        end

        context 'when creating related epic link fails' do
          before do
            allow_next_instance_of(Epic::RelatedEpicLink) do |instance|
              allow(instance).to receive(:save).and_return(false)

              errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:source, 'error message') }
              allow(instance).to receive(:errors).and_return(errors)
            end
          end

          it 'does not create relationship', :aggregate_failures do
            error_message = "#{epic_b.to_reference} cannot be added: error message"
            service_result = execute

            expect { service_result }.to not_change { Epic::RelatedEpicLink.count }
              .and not_change { WorkItems::RelatedWorkItemLink.count }

            expect(service_result).to eq(message: error_message, status: :error, http_status: 422)
          end
        end
      end
    end

    context 'event tracking' do
      shared_examples 'a recorded event' do
        it 'records event for each link created' do
          params = {
            link_type: link_type,
            issuable_references: [issuable_a, issuable3].map { |epic| epic.to_reference(issuable.group, full: true) }
          }

          expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(tracking_method_name)
            .with(author: user, namespace: group).twice

          described_class.new(issuable, user, params).execute
        end
      end

      context 'for relates_to link type' do
        let(:link_type) { IssuableLink::TYPE_RELATES_TO }
        let(:tracking_method_name) { :track_linked_epic_with_type_relates_to_added }

        it_behaves_like 'a recorded event'
      end

      context 'for blocks link_type' do
        let(:link_type) { IssuableLink::TYPE_BLOCKS }
        let(:tracking_method_name) { :track_linked_epic_with_type_blocks_added }

        it_behaves_like 'a recorded event'
      end

      context 'for is_blocked_by link_type' do
        let(:link_type) { IssuableLink::TYPE_IS_BLOCKED_BY }
        let(:tracking_method_name) { :track_linked_epic_with_type_is_blocked_by_added }

        it_behaves_like 'a recorded event'
      end
    end
  end
end
