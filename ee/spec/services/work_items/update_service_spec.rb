# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::UpdateService, feature_category: :team_planning do
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, developers: developer) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item, refind: true) { create(:work_item, project: project) }

  let(:current_user) { developer }
  let(:params) { {} }

  describe '#execute' do
    let(:service) do
      described_class.new(
        container: project,
        current_user: current_user,
        params: params,
        widget_params: widget_params
      )
    end

    subject(:update_work_item) { service.execute(work_item) }

    it_behaves_like 'work item widgetable service' do
      let(:widget_params) do
        {
          weight_widget: { weight: 1 }
        }
      end

      let(:service_execute) { subject }

      let(:supported_widgets) do
        [
          {
            klass: WorkItems::Widgets::WeightService::UpdateService,
            callback: :before_update_callback, params: { weight: 1 }
          }
        ]
      end
    end

    context 'when updating widgets' do
      context 'for the progress widget' do
        let(:widget_params) { { progress_widget: { progress: 50 } } }

        before do
          stub_licensed_features(okrs: true)
        end

        it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
          subject(:execute_service) { update_work_item }
        end
      end

      context 'for the weight widget' do
        let(:widget_params) { { weight_widget: { weight: new_weight } } }

        before do
          stub_licensed_features(issue_weights: true)

          work_item.update!(weight: 1)
        end

        context 'when weight is changed' do
          let(:new_weight) { nil }

          it "triggers 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).to receive(:issuable_weight_updated).with(work_item).and_call_original

            subject
          end

          it_behaves_like 'update service that triggers GraphQL work_item_updated subscription' do
            subject(:execute_service) { update_work_item }
          end
        end

        context 'when weight remains unchanged' do
          let(:new_weight) { 1 }

          it "does not trigger 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_weight_updated)

            subject
          end
        end

        context 'when weight widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableWeightUpdated' for issuable weight update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_weight_updated)

            subject
          end
        end
      end

      context 'for the iteration widget' do
        let_it_be(:cadence) { create(:iterations_cadence, group: group) }
        let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }

        let(:widget_params) { { iteration_widget: { iteration: new_iteration } } }

        before do
          stub_licensed_features(iterations: true)

          work_item.update!(iteration: nil)
        end

        context 'when iteration is changed' do
          let(:new_iteration) { iteration }

          it "triggers 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).to receive(:issuable_iteration_updated).with(work_item).and_call_original

            subject
          end
        end

        context 'when iteration remains unchanged' do
          let(:new_iteration) { nil }

          it "does not trigger 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_iteration_updated)

            subject
          end
        end

        context 'when iteration widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableIterationUpdated' for issuable iteration update subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_iteration_updated)

            subject
          end
        end
      end

      context 'for the health_status widget' do
        let(:widget_params) { { health_status_widget: { health_status: new_health_status } } }

        before do
          stub_licensed_features(issuable_health_status: true)

          work_item.update!(health_status: :needs_attention)
        end

        context 'when health_status is changed' do
          let(:new_health_status) { :on_track }

          it "triggers 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).to receive(:issuable_health_status_updated).with(work_item).and_call_original

            subject
          end
        end

        context 'when health_status remains unchanged' do
          let(:new_health_status) { :needs_attention }

          it "does not trigger 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_health_status_updated)

            subject
          end
        end

        context 'when health_status widget param is not provided' do
          let(:widget_params) { {} }

          it "does not trigger 'issuableHealthStatusUpdated' subscription" do
            expect(GraphqlTriggers).not_to receive(:issuable_health_status_updated)

            subject
          end
        end
      end

      context 'for color widget' do
        let_it_be(:work_item, refind: true) { create(:work_item, :epic, namespace: group) }
        let_it_be(:default_color) { '#1068bf' }

        let(:new_color) { '#c91c00' }

        before do
          stub_licensed_features(epic_colors: true)
        end

        context 'when work item has a color' do
          let_it_be(:existing_color) { create(:color, work_item: work_item, color: '#0052cc') }

          context 'when color changes' do
            let(:widget_params) { { color_widget: { color: new_color } } }

            it 'updates existing color' do
              expect { subject }.not_to change { WorkItems::Color.count }

              expect(work_item.color.color.to_s).to eq(new_color)
              expect(work_item.color.issue_id).to eq(work_item.id)
            end

            it 'creates system notes' do
              expect(SystemNoteService).to receive(:change_color_note)
               .with(work_item, current_user, existing_color.color.to_s)
               .and_call_original

              expect { subject }.to change { Note.count }.by(1)
              expect(work_item.notes.last.note).to eq("changed color from `#{existing_color.color}` to `#{new_color}`")
            end
          end

          context 'when color remains unchanged' do
            let(:widget_params) { {} }

            it 'does not update color' do
              expect { subject }.to not_change { WorkItems::Color.count }.and not_change { Note.count }
              expect(work_item.color.color.to_s).to eq(existing_color.color.to_s)
            end
          end

          context 'when color param is the same as the work item color' do
            let(:widget_params) { { color_widget: { color: existing_color.color.to_s } } }

            it 'does not update color' do
              expect { subject }.to not_change { WorkItems::Color.count }.and not_change { Note.count }
            end
          end

          context 'when widget is not supported in the new type' do
            let(:widget_params) { { color_widget: { color: new_color } } }

            before do
              allow_next_instance_of(WorkItems::Callbacks::Color) do |instance|
                allow(instance).to receive(:excluded_in_new_type?).and_return(true)
              end
            end

            it 'removes color' do
              expect { subject }.to change { work_item.reload.color }.from(existing_color).to(nil)
            end

            it 'creates system notes' do
              expect(SystemNoteService).to receive(:change_color_note)
                .with(work_item, current_user, nil)
                .and_call_original

              expect { subject }.to change { Note.count }.by(1)
              expect(Note.last.note).to eq("removed color `#{existing_color.color}`")
            end
          end
        end

        context 'when work item has no color' do
          let(:widget_params) { { color_widget: { color: new_color } } }

          it 'creates a new color record' do
            expect { subject }.to change { WorkItems::Color.count }.by(1)

            expect(work_item.color.color.to_s).to eq(new_color)
            expect(work_item.color.issue_id).to eq(work_item.id)
          end

          it 'creates system notes' do
            expect(SystemNoteService).to receive(:change_color_note)
              .with(work_item, current_user, nil)
              .and_call_original

            expect { subject }.to change { Note.count }.by(1)
            expect(work_item.notes.last.note).to eq("set color to `#{new_color}`")
          end
        end
      end

      context 'for rolledup dates widget' do
        let_it_be(:work_item, refind: true) { create(:work_item, :epic, namespace: group) }

        context 'when widget params are present' do
          let_it_be(:dates_source) do
            create(
              :work_items_dates_source,
              work_item: work_item,
              start_date: 1.day.ago,
              due_date: 1.day.from_now,
              due_date_is_fixed: true,
              start_date_is_fixed: true)
          end

          let(:widget_params) do
            { rolledup_dates_widget: { start_date_is_fixed: false, due_date_is_fixed: false } }
          end

          it 'updates rolledup dates' do
            expect(WorkItems::Widgets::RolledupDatesService::HierarchyUpdateService)
              .to receive(:new)
              .with(work_item)
              .and_call_original

            expect { subject }.not_to change { WorkItems::DatesSource.count }

            expect(work_item.dates_source.due_date_is_fixed).to be_falsey
            expect(work_item.dates_source.start_date_is_fixed).to be_falsey
          end
        end

        context 'when widget params are not present' do
          let(:widget_params) { { rolledup_dates_widget: {} } }

          it 'does not update rolledup dates' do
            expect(WorkItems::Widgets::RolledupDatesService::HierarchyUpdateService)
              .not_to receive(:new)

            expect { subject }.not_to change { WorkItems::DatesSource.count }
          end
        end
      end
    end

    context 'with a synced epic' do
      let_it_be(:work_item, refind: true) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:epic) { work_item.synced_epic }
      let(:start_date) { (Time.current + 1.day).to_date }
      let(:due_date) { (Time.current + 2.days).to_date }

      let(:service) do
        described_class.new(
          container: group,
          current_user: current_user,
          params: params,
          widget_params: widget_params
        )
      end

      let(:widget_params) do
        {
          description_widget: {
            description: 'new description'
          },
          color_widget: {
            color: '#FF0000'
          },
          start_and_due_date_widget: { start_date: start_date, due_date: due_date }
        }
      end

      let(:params) do
        {
          confidential: true,
          title: 'new title',
          external_key: 'external_key'
        }
      end

      before_all do
        group.add_developer(developer)
      end

      before do
        stub_feature_flags(synced_epic_work_item_editable: true)
        stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      end

      subject(:execute) { update_work_item }

      it_behaves_like 'syncs all data from a work_item to an epic'

      context 'when only providing title and description' do
        let(:widget_params) do
          {
            description_widget: {
              description: 'new description'
            }
          }
        end

        it_behaves_like 'syncs all data from a work_item to an epic'
      end

      it 'syncs the data to the epic', :aggregate_failures do
        update_work_item

        expect(epic.reload.title).to eq('new title')
        expect(work_item.reload.title).to eq('new title')
        expect(epic.title_html).to eq(work_item.title_html)

        expect(epic.last_edited_by).to eq(current_user)

        expect(epic.updated_at).to eq(work_item.updated_at)

        expect(epic.description).to eq('new description')
        expect(work_item.description).to eq('new description')
        expect(epic.description_html).to eq(work_item.description_html)

        expect(epic.reload.confidential).to eq(true)
        expect(work_item.confidential).to eq(true)

        expect(work_item.color.color.to_s).to eq('#FF0000')
        expect(epic.color.to_s).to eq('#FF0000')

        expect(work_item.start_date).to eq(start_date)
        expect(work_item.due_date).to eq(due_date)

        expect(epic.start_date).to eq(start_date)
        expect(epic.due_date).to eq(due_date)
      end

      context 'when updating labels' do
        let_it_be(:label_on_epic) { create(:group_label, group: group) }
        let_it_be(:label_on_epic_work_item) { create(:group_label, group: group) }
        let_it_be(:new_labels) { create_list(:group_label, 2, group: group) }

        let(:labels_widget) { {} }
        let(:labels_params) { {} }
        let(:service) do
          described_class.new(
            container: group,
            current_user: current_user,
            params: params.merge(labels_params),
            widget_params: widget_params.merge(labels_widget)
          )
        end

        before do
          epic.labels << label_on_epic
          epic.work_item.labels << label_on_epic_work_item
        end

        context 'and replacing labels with `label_ids` param' do
          let(:labels_params) { { label_ids: new_labels.map(&:id) } }
          let(:expected_labels) { new_labels }
          let(:expected_epic_own_labels) { [] }
          let(:expected_epic_work_item_own_labels) { new_labels }

          it_behaves_like 'syncs labels between epics and epic work items'
        end

        context 'and adding and removing labels through params' do
          context 'and removing label assigned to epic' do
            let(:labels_params) { { add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic.id] } }
            let(:expected_labels) { [new_labels, label_on_epic_work_item].flatten }
            let(:expected_epic_own_labels) { [] }
            let(:expected_epic_work_item_own_labels) { [new_labels, label_on_epic_work_item].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end

          context 'and removing label assigned to epic work item' do
            let(:labels_params) do
              { add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic_work_item.id] }
            end

            let(:expected_labels) { [new_labels, label_on_epic].flatten }
            let(:expected_epic_own_labels) { [label_on_epic] }
            let(:expected_epic_work_item_own_labels) { [new_labels].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end
        end

        context 'and adding and removing labels through widget params' do
          context 'and removing label assigned to epic' do
            let(:labels_widget) do
              { labels_widget: { add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic.id] } }
            end

            let(:expected_labels) { [new_labels, label_on_epic_work_item].flatten }
            let(:expected_epic_own_labels) { [] }
            let(:expected_epic_work_item_own_labels) { [new_labels, label_on_epic_work_item].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end

          context 'and removing label assigned to epic work item' do
            let(:labels_widget) do
              {
                labels_widget: {
                  add_label_ids: new_labels.map(&:id), remove_label_ids: [label_on_epic_work_item.id]
                }
              }
            end

            let(:expected_labels) { [new_labels, label_on_epic].flatten }
            let(:expected_epic_own_labels) { [label_on_epic] }
            let(:expected_epic_work_item_own_labels) { [new_labels].flatten }

            it_behaves_like 'syncs labels between epics and epic work items'
          end
        end
      end

      context 'when updating the work item fails' do
        before do
          allow_next_found_instance_of(WorkItem) do |work_item|
            allow(work_item).to receive(:update).and_return(false)
          end
        end

        it 'does not update the epic or work item' do
          expect { execute }
            .to not_change { work_item.reload }
            .and not_change { epic.reload }
        end
      end

      context 'when updating the epic fails' do
        before do
          allow_next_found_instance_of(Epic) do |epic|
            allow(epic).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
          end
        end

        it 'does not update the work item' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to update epic",
              error_message: "Record invalid",
              group_id: group.id,
              work_item_id: work_item.id
            })

          expect { execute }
            .to not_change { work_item.reload }
            .and not_change { epic.reload }
            .and raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context 'when changes are invalid' do
        let(:widget_params) { {} }
        let(:params) { { title: '' } }

        it 'does not propagate them to the epic' do
          expect { execute }
            .to not_change { work_item.reload.title }
            .and not_change { epic.reload.title }
        end
      end

      context 'when work item has no synced epic' do
        let_it_be(:work_item, refind: true) { create(:work_item, :epic, namespace: group) }

        it 'does not error and updates the work item' do
          expect { execute }.not_to raise_error

          expect(work_item.reload.title).to eq('new title')
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(synced_epic_work_item_editable: true, sync_work_item_to_epic: false)
        end

        it 'updates work item but not the epic' do
          expect { execute }
            .to change { work_item.reload.title }
            .and not_change { epic.reload.title }
        end
      end

      context 'when work item record is outdated' do
        let(:widget_params) { {} }
        let(:params) do
          {
            title: 'new title'
          }
        end

        context 'for base attributes' do
          before do
            epic.update!(confidential: true)
            work_item.update!(confidential: false)
          end

          it 'only syncs changed attributes' do
            expect { execute }
              .to change { epic.reload.title }
              .and not_change { epic.reload.confidential }
          end
        end

        context 'for color' do
          before do
            epic.update!(color: '#FF0000')
            work_item.build_color
            work_item.color.update!(color: '#00FF00')
          end

          it 'does not sync when color did not change as part of the request' do
            expect { execute }.to not_change { epic.reload.color.to_s }
          end
        end

        context 'for dates' do
          before do
            epic.update!(start_date: start_date, due_date: due_date)
            work_item.update!(start_date: start_date + 1.day, due_date: due_date + 1.day)
          end

          it 'does not sync when date did not change as part of the request' do
            expect { execute }.to not_change { epic.reload.start_date }.and not_change { epic.reload.due_date }
          end
        end
      end
    end
  end
end
