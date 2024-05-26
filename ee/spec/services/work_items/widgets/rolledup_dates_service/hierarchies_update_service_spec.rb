# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
  :aggregate_failures,
  feature_category: :team_planning do
    let_it_be(:group) { create(:group) }
    let_it_be(:start_date) { 1.day.ago.to_date }
    let_it_be(:due_date) { 1.day.from_now.to_date }

    let_it_be_with_reload(:milestone) do
      create(:milestone, group: group, start_date: start_date, due_date: due_date)
    end

    let_it_be(:work_item_1) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be(:work_item_2) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    subject(:service) { described_class.new(WorkItem.id_in([work_item_1.id, work_item_2.id])) }

    it "enqueues the parent epic update" do
      parent = create(:work_item, :epic, namespace: group).tap do |parent|
        create(:parent_link, work_item: work_item_1, work_item_parent: parent)
      end

      expect(::WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker)
        .to receive(:perform_async)
        .with([parent.id])

      service.execute
    end

    it "updates the start_date and due_date from milestone" do
      expect { service.execute }
        .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
    end

    context "and the minimal start date comes from a child work_item" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :issue, namespace: group, start_date: earliest_start_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
      end
    end

    context "and the maximum due date comes from a child work_item" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :issue, namespace: group, due_date: latest_due_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
      end
    end

    context "and the minimal start date comes from a child work_item's dates_source" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :issue, namespace: group) do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, start_date: earliest_start_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
      end
    end

    context "and the maximum due date comes from a child work_item's dates_source" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :issue, namespace: group).tap do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, due_date: latest_due_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
      end
    end
  end
