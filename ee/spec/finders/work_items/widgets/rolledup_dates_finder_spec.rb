# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::RolledupDatesFinder, :aggregate_failures, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:epic_work_item) { create(:work_item, :epic, namespace: group) }

  let_it_be(:child_work_item) do
    create(
      :work_item,
      :issue,
      namespace: group,
      start_date: 1.day.ago,
      due_date: 1.day.from_now
    ).tap do |work_item|
      create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
    end
  end

  subject(:finder) { described_class.new(epic_work_item) }

  describe '#minimum_start_date' do
    it 'returns a WorkItems::DatesSource query' do
      start_date = finder.minimum_start_date

      expect(start_date).to be_a(ActiveRecord::Relation)
      expect(start_date.first.attributes).to eq(
        'issue_id' => nil,
        'start_date' => child_work_item.start_date,
        'start_date_sourcing_work_item_id' => child_work_item.id,
        'start_date_sourcing_milestone_id' => nil)
    end
  end

  describe '#maximum_due_date' do
    it 'returns a WorkItems::DatesSource query' do
      due_date = finder.maximum_due_date

      expect(due_date).to be_a(ActiveRecord::Relation)
      expect(due_date.first.attributes).to eq(
        'issue_id' => nil,
        'due_date' => child_work_item.due_date,
        'due_date_sourcing_work_item_id' => child_work_item.id,
        'due_date_sourcing_milestone_id' => nil)
    end
  end

  describe '#attributes_for' do
    it 'raises an error when an unknown field is given' do
      expect { finder.attributes_for(:foobar) }
        .to raise_error(ArgumentError, "unknown field 'foobar'")
    end

    context 'when the wider range comes from a child work_item' do
      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => child_work_item.start_date,
          'start_date_sourcing_work_item_id' => child_work_item.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => child_work_item.due_date,
          'due_date_sourcing_work_item_id' => child_work_item.id,
          'due_date_sourcing_milestone_id' => nil)
      end
    end

    context 'when the wider range comes from a child work_item dates source' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          start_date: 2.days.ago.to_date,
          due_date: 2.days.from_now.to_date)
      end

      let_it_be(:dates_source) do
        create(
          :work_items_dates_source,
          :fixed,
          work_item: child_work_item,
          start_date: 3.days.ago,
          due_date: 3.days.from_now)
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => child_work_item.dates_source.start_date,
          'start_date_sourcing_work_item_id' => child_work_item.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => child_work_item.dates_source.due_date,
          'due_date_sourcing_work_item_id' => child_work_item.id,
          'due_date_sourcing_milestone_id' => nil)
      end
    end

    context 'when the wider range comes from a child work_item milestone' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          start_date: 3.days.ago.to_date,
          due_date: 3.days.from_now.to_date)
      end

      let_it_be(:dates_source) do
        create(
          :work_items_dates_source,
          :fixed,
          work_item: child_work_item,
          start_date: 2.days.ago,
          due_date: 2.days.from_now)
      end

      before do
        child_work_item.update!(milestone: milestone)
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => milestone.start_date,
          'start_date_sourcing_work_item_id' => nil,
          'start_date_sourcing_milestone_id' => milestone.id)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => milestone.due_date,
          'due_date_sourcing_work_item_id' => nil,
          'due_date_sourcing_milestone_id' => milestone.id)
      end
    end

    context 'when the wider range comes from different sources' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          due_date: 3.days.from_now.to_date)
      end

      before do
        child_work_item.update!(milestone: milestone)
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => child_work_item.start_date,
          'start_date_sourcing_work_item_id' => child_work_item.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => milestone.due_date,
          'due_date_sourcing_work_item_id' => nil,
          'due_date_sourcing_milestone_id' => milestone.id)
      end
    end
  end
end
