# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::CreateService, feature_category: :team_planning do
  RSpec.shared_examples 'creates work item in container' do |container_type|
    include_context 'with container for work items service', container_type

    describe '#execute' do
      subject(:service_result) { service.execute }

      before do
        stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      end

      context 'when user is not allowed to create a work item in the container' do
        let(:current_user) { user_with_no_access }

        it { is_expected.to be_error }

        it 'returns an access error' do
          expect(service_result.errors).to contain_exactly('Operation not allowed')
        end
      end

      context 'when params are valid' do
        let(:type) { WorkItems::Type.default_by_type(:task) }
        let(:opts) { { title: 'Awesome work_item', description: 'please fix', work_item_type: type } }

        it 'created instance is a WorkItem' do
          expect(Issuable::CommonSystemNotesService).to receive_message_chain(:new, :execute)

          work_item = service_result[:work_item]

          expect(work_item).to be_persisted
          expect(work_item).to be_a(::WorkItem)
          expect(work_item.title).to eq('Awesome work_item')
          expect(work_item.description).to eq('please fix')
          expect(work_item.work_item_type.base_type).to eq('task')
        end

        it 'calls NewIssueWorker with correct arguments' do
          expect(NewIssueWorker).to receive(:perform_async)
                                      .with(Integer, current_user.id, 'WorkItem')

          service_result
        end

        describe 'with color widget params' do
          let(:widget_params) { { color_widget: { color: '#c91c00' } } }

          before do
            skip 'these examples only apply to a group container' unless container.is_a?(Group)
          end

          context 'when user can admin_work_item' do
            let(:current_user) { reporter }

            context 'when type does not support color widget' do
              it 'creates new work item without setting color' do
                expect { service_result }.to change { WorkItem.count }.by(1).and(
                  not_change { WorkItems::Color.count }
                )
                expect(service_result[:work_item].color).to be_nil
                expect(service_result[:status]).to be(:success)
              end
            end

            context 'when type supports color widget' do
              let(:type) { WorkItems::Type.default_by_type(:epic) }

              it 'creates new work item and sets color' do
                expect { service_result }.to change { WorkItem.count }.by(1).and(
                  change { WorkItems::Color.count }.by(1)
                )
                expect(service_result[:work_item].color.color.to_s).to eq('#c91c00')
                expect(service_result[:status]).to be(:success)
              end
            end
          end
        end
      end
    end
  end

  it_behaves_like 'creates work item in container', :project
  it_behaves_like 'creates work item in container', :project_namespace
  it_behaves_like 'creates work item in container', :group

  context 'for legacy epics' do
    include_context 'with container for work items service', :group

    let_it_be(:parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be(:other_child_epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be(:other_child_issue) { create(:work_item, namespace: group) }
    let_it_be(:parent_link_epic) do
      create(:parent_link, work_item_parent: parent, work_item: other_child_epic, relative_position: 500)
    end

    let_it_be(:parent_link_issue) do
      create(:parent_link, work_item_parent: parent, work_item: other_child_issue, relative_position: 600)
    end

    let_it_be(:epic_issue) do
      create(:epic_issue, epic: parent.synced_epic, issue: other_child_issue, relative_position: 600)
    end

    let(:epic) { Epic.last }
    let(:type) { WorkItems::Type.default_by_type(:epic) }

    let(:start_date) { (Time.current + 1.day).to_date }
    let(:due_date) { (Time.current + 2.days).to_date }

    let(:widget_params) do
      {
        description_widget: {
          description: 'new description'
        },
        color_widget: {
          color: '#FF0000'
        },
        start_and_due_date_widget: { start_date: start_date, due_date: due_date },
        hierarchy_widget: { parent: parent }
      }
    end

    let(:opts) { { title: 'new title', external_key: 'external_key', confidential: true, work_item_type: type } }
    let(:current_user) { reporter }

    before do
      stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      stub_feature_flags(synced_epic_work_item_editable: true)
    end

    subject(:service_result) { service.execute }

    it_behaves_like 'syncs all data from a work_item to an epic'

    context 'when creating the epic with only title and description' do
      let(:widget_params) do
        {
          description_widget: {
            description: 'new description'
          }
        }
      end

      it_behaves_like 'syncs all data from a work_item to an epic'
    end

    context 'when creating an epic work item' do
      it 'creates the epic with correct relative_position' do
        work_item = service_result.payload[:work_item]

        expect(work_item.reload.parent_link.relative_position).to eq(work_item.synced_epic.relative_position)
      end
    end

    context 'when creating an issue with a synced epic as parent' do
      let(:type) { WorkItems::Type.default_by_type(:issue) }

      it 'creates the work item and the EpicIssue with the correct relative_position' do
        expect { service_result }
          .to change { EpicIssue.count }.by(1)
          .and change { WorkItems::ParentLink.count }.by(1)

        work_item = service_result.payload[:work_item]

        expect(work_item.parent_link.relative_position).to eq(work_item.epic_issue.relative_position)
      end
    end

    context 'when not creating an epic work item' do
      let(:type) { WorkItems::Type.default_by_type(:task) }

      let_it_be(:parent) { nil }

      it 'only creates a work item' do
        expect { service_result }
          .to not_change { Epic.count }
          .and change { WorkItem.count }
      end
    end

    context 'when creating the work item fails' do
      before do
        allow_next_instance_of(WorkItem) do |work_item|
          allow(work_item).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
        end
      end

      it 'does not update the epic or work item' do
        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
          .with({
            message: "Not able to create epic",
            error_message: "Record invalid",
            group_id: group.id,
            work_item_id: an_instance_of(Integer)
          })

        expect { service_result }
          .to not_change { Epic.count }
          .and not_change { WorkItem.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when creating the epic fails' do
      it 'does not create an epic or work item' do
        allow(Epic).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)

        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
          .with({
            message: "Not able to create epic",
            error_message: "Record invalid",
            group_id: group.id,
            work_item_id: an_instance_of(Integer)
          })

        expect { service_result }
          .to not_change { WorkItem.count }
          .and not_change { Epic.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when changes are invalid' do
      let(:widget_params) { {} }
      let(:opts) { { title: '' } }

      it 'does not create an epic or work item' do
        expect { service_result }
          .to not_change { WorkItem.count }
          .and not_change { Epic.count }
      end
    end
  end
end
