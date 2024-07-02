# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::WorkItems::Widgets::RolledupDatesService::HierarchyUpdateService,
  :aggregate_failures,
  feature_category: :portfolio_management do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }
    let(:synced_attributes) do
      [
        :start_date,
        :start_date_fixed,
        :start_date_is_fixed,
        :start_date_sourcing_milestone_id,
        :due_date,
        :due_date_fixed,
        :due_date_is_fixed,
        :due_date_sourcing_milestone_id
      ]
    end

    shared_examples 'work item with synced epic' do
      let_it_be_with_reload(:epic) { create(:epic, work_item: work_item) }

      it 'syncs date fields with epic', :aggregate_failures do
        expect { described_class.new(work_item).execute }
          .to change { work_item.reload.dates_source&.attributes }
          .and change { epic.reload.attributes.except('color') }
          .and not_change { epic.reload.updated_at }

        synced_attributes.each do |attribute|
          expect(work_item.dates_source[attribute]).to eq(epic.public_send(attribute))
        end

        dates_source = work_item.reload.dates_source

        expect(dates_source).to be_present
        expect(dates_source.start_date_sourcing_work_item&.synced_epic&.id)
          .to eq(epic.start_date_sourcing_epic_id)
        expect(dates_source.due_date_sourcing_work_item&.synced_epic&.id)
          .to eq(epic.due_date_sourcing_epic_id)
      end
    end

    shared_examples "does not update work_item's date_source" do
      specify do
        expect { described_class.new(work_item).execute }
          .to not_change { work_item&.reload&.dates_source&.start_date }
          .and not_change { work_item&.reload&.dates_source&.due_date }
      end
    end

    shared_examples "enqueue the parent epic update" do
      context "when the work_item does not have an epic parent" do
        specify do
          expect(::WorkItems::RolledupDates::UpdateRolledupDatesWorker)
            .not_to receive(:perform_async)

          described_class.new(work_item).execute
        end
      end

      context "when previous_work_item_parent_id is given" do
        specify do
          expect(::WorkItems::RolledupDates::UpdateRolledupDatesWorker)
            .to receive(:perform_async)
              .with(1)

          described_class.new(work_item, 1).execute
        end
      end

      context "when work_item has a parent" do
        let_it_be(:parent) do
          create(:work_item, :epic, namespace: group).tap do |parent|
            create(:parent_link, work_item: work_item, work_item_parent: parent)
          end
        end

        specify do
          expect(::WorkItems::RolledupDates::UpdateRolledupDatesWorker)
            .to receive(:perform_async)
            .with(parent.id)

          described_class.new(work_item).execute
        end
      end
    end

    shared_examples "when work item already have an associated dates_source" do
      after do
        work_item.dates_source.delete
      end

      context "when rolling up start and due date" do
        before do
          create(:work_items_dates_source, work_item: work_item)
        end

        it "updates start date and due date" do
          expect { described_class.new(work_item).execute }
            .to not_change { WorkItems::DatesSource.count }
            .and change { work_item.reload.dates_source&.due_date }.from(nil).to(due_date)
            .and change { work_item.reload.dates_source&.start_date }.from(nil).to(start_date)
        end
      end

      context "when due date is fixed" do
        before do
          create(:work_items_dates_source, work_item: work_item, due_date_is_fixed: true)
        end

        it "updates start date and does not update due date" do
          expect { described_class.new(work_item).execute }
            .to not_change { WorkItems::DatesSource.count }
            .and not_change { work_item.reload.dates_source&.due_date }
            .and change { work_item.reload.dates_source&.start_date }.from(nil).to(start_date)
        end

        it_behaves_like 'work item with synced epic'
      end

      context "when start date is fixed" do
        before do
          create(:work_items_dates_source, work_item: work_item, start_date_is_fixed: true)
        end

        it "updates due date and does not update start date" do
          expect { described_class.new(work_item).execute }
            .to not_change { WorkItems::DatesSource.count }
            .and not_change { work_item.reload.dates_source&.start_date }
            .and change { work_item.reload.dates_source&.due_date }.from(nil).to(due_date)
        end

        it_behaves_like 'work item with synced epic'
      end

      context 'when start date and due date are fixed' do
        let_it_be_with_reload(:epic) { create(:epic, work_item: work_item) }

        before do
          create(:work_items_dates_source, work_item: work_item, due_date_is_fixed: true, start_date_is_fixed: true)
        end

        it 'syncs associated epic dates' do
          expect { described_class.new(work_item).execute }
            .to not_change { work_item.reload.dates_source&.attributes }
            .and change { epic.reload.attributes.except('color') }
            .and not_change { epic.reload.updated_at }

          synced_attributes.each do |attribute|
            expect(work_item.dates_source[attribute]).to eq(epic.public_send(attribute))
          end
        end
      end

      it_behaves_like 'work item with synced epic'
    end

    shared_examples "when work item does not have an associated dates_source" do
      it "updates work_item dates_source with the child start/due date" do
        expect { described_class.new(work_item).execute }
          .to change { WorkItems::DatesSource.count }.by(1)
          .and change { work_item.reload.dates_source&.start_date }.from(nil).to(start_date)
          .and change { work_item.reload.dates_source&.due_date }.from(nil).to(due_date)
      end

      it_behaves_like 'work item with synced epic'
    end

    context "when not rolling up dates" do
      context "when the :work_items_rolledup_dates feature flag is disabled" do
        before do
          stub_feature_flags(work_items_rolledup_dates: false)
        end

        it_behaves_like "does not update work_item's date_source"
      end

      context "when given work_item is blank" do
        let(:work_item) { nil }

        it_behaves_like "does not update work_item's date_source"
      end

      context "when given work_item does not have children" do
        let(:work_item) { create(:work_item, :issue) }

        it_behaves_like "does not update work_item's date_source"
      end
    end

    context "when rolling up dates" do
      let_it_be(:start_date) { 1.day.ago.to_date }
      let_it_be(:due_date) { 1.day.from_now.to_date }

      context "when rolling up from child work_item dates fields" do
        before_all do
          create(:work_item, :epic, namespace: group, start_date: start_date, due_date: due_date).tap do |child|
            create(:epic, work_item: child)
            create(:parent_link, work_item: child, work_item_parent: work_item)
          end
        end

        it_behaves_like "enqueue the parent epic update"
        it_behaves_like "when work item already have an associated dates_source"
        it_behaves_like "when work item does not have an associated dates_source"
      end

      context "when rolling up from a child work_item dates_source fields" do
        before_all do
          create(:work_item, :epic, namespace: group).tap do |child|
            create(:epic, work_item: child)
            create(:parent_link, work_item: child, work_item_parent: work_item)
            create(:work_items_dates_source, :fixed, work_item: child, start_date: start_date, due_date: due_date)
          end
        end

        it_behaves_like "enqueue the parent epic update"
        it_behaves_like "when work item already have an associated dates_source"
        it_behaves_like "when work item does not have an associated dates_source"
      end

      context "when rolling up from from a child work_item milestone fields" do
        let_it_be(:milestone) do
          create(:milestone, group: group, start_date: start_date, due_date: due_date)
        end

        before_all do
          create(:work_item, :issue, namespace: group, milestone: milestone).tap do |child|
            create(:parent_link, work_item: child, work_item_parent: work_item)
            create(
              :work_items_dates_source,
              :fixed,
              work_item: child,
              start_date: start_date + 1.day,
              due_date: due_date - 1.day
            )
          end
        end

        it_behaves_like "enqueue the parent epic update"
        it_behaves_like "when work item already have an associated dates_source"
        it_behaves_like "when work item does not have an associated dates_source"
      end

      context "when all children are removed from the hierarchy", :sidekiq_inline, :clean_gitlab_redis_shared_state do
        let_it_be(:child_work_item) do
          create(:work_item, :issue, namespace: group, start_date: start_date, due_date: due_date)
            .tap do |child|
              # Simulate that the dates were rolled up at some point
              create(
                :work_items_dates_source,
                work_item: work_item,
                start_date: start_date,
                start_date_sourcing_work_item_id: child.id,
                due_date: due_date,
                due_date_sourcing_work_item_id: child.id
              )
            end
        end

        it "nullify the start/due date" do
          expect { described_class.new(child_work_item, work_item.id).execute }
            .to change { work_item.reload.dates_source&.due_date }.from(due_date).to(nil)
            .and change { work_item.reload.dates_source&.start_date }.from(start_date).to(nil)
        end

        it_behaves_like 'work item with synced epic'
      end
    end
  end
