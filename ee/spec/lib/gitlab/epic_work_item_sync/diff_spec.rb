# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EpicWorkItemSync::Diff, feature_category: :team_planning do
  let(:strict_equal) { false }

  describe '#attributes' do
    subject(:attributes) { described_class.new(epic, work_item, strict_equal: strict_equal).attributes }

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group) }
    let(:work_item) { epic.work_item }

    context 'when epic and work item are equal' do
      it { is_expected.to be_empty }
    end

    describe 'base attributes' do
      context 'when epic and work base attributes are not equal' do
        let(:title) { "Other title" }
        let(:expected_differences) { %w[title lock_version] }

        before do
          epic.update!(title: title)
        end

        it 'returns a list of attributes that are different' do
          expect(attributes).to match_array(expected_differences)
        end
      end

      context 'when updated_at is within a 1 second range' do
        let_it_be(:updated_at) { Time.current }

        before do
          epic.update!(updated_at: updated_at)
          work_item.update!(updated_at: updated_at + 0.9.seconds)
        end

        it { is_expected.to be_empty }
      end

      context 'when updated_at exceeds 1 second difference' do
        let_it_be(:updated_at) { Time.current }

        before do
          epic.update!(updated_at: updated_at)
          work_item.update!(updated_at: updated_at + 1.second)
        end

        it { is_expected.to include("updated_at") }
      end
    end

    describe 'namespace' do
      context 'when epic has a different group_id than the work item namespace_id' do
        before do
          epic.update!(group: create(:group))
        end

        it { is_expected.to include("namespace") }
      end
    end

    describe 'color' do
      context 'when epic color is equal to work item color' do
        before do
          create(:color, work_item: work_item, color: '#0052cc')
          epic.update!(color: '#0052cc')
        end

        it { is_expected.not_to include("color") }
      end

      context 'when epic color is the default color and work item color is nil' do
        before do
          epic.update!(color: Epic::DEFAULT_COLOR)
        end

        it { is_expected.to be_empty }
      end

      context 'when epic color is not the default color and work item color is nil' do
        before do
          epic.update!(color: '#123456')
        end

        it { is_expected.to include("color") }
      end
    end

    describe 'hierarchy' do
      let_it_be(:parent_epic) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group, parent: parent_epic) }

      context 'when epic and work item hierarchy are equal' do
        before do
          create(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic.work_item)
        end

        it { is_expected.to be_empty }
      end

      context 'when epic and work item hierarchy are not equal' do
        before do
          create(:parent_link, work_item_parent: create(:work_item, :epic), work_item: epic.work_item)
        end

        it { is_expected.to include("parent_id") }
      end

      context 'with relative position check' do
        let_it_be_with_reload(:epic) do
          create(:epic, :with_synced_work_item, group: group, parent: parent_epic, relative_position: 10)
        end

        context 'when relative_position is equal' do
          before do
            create(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic.work_item,
              relative_position: 10)
          end

          it { is_expected.to be_empty }
        end

        context 'when relative_position is not equal' do
          before do
            create(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic.work_item,
              relative_position: 11)
          end

          it { is_expected.to include("relative_position") }
        end

        context 'when work_item_parent_link record is missing' do
          it { is_expected.not_to include("relative_position") }
          it { is_expected.to include("parent_id") }
        end
      end
    end

    describe 'start dates' do
      let_it_be(:expected_start_date) { Time.current.to_date }
      let_it_be(:expected_due_date) { expected_start_date + 2.days }
      let_it_be_with_reload(:epic) do
        create(:epic, :with_synced_work_item, group: group, start_date_fixed: expected_start_date,
          due_date_fixed: expected_due_date, start_date_is_fixed: true, due_date_is_fixed: true
        )
      end

      context 'when it is equal' do
        before do
          create(
            :work_items_dates_source,
            :fixed,
            work_item: work_item,
            start_date: expected_start_date,
            due_date: expected_due_date)
        end

        it { is_expected.to be_empty }
      end

      context 'when it is different' do
        it { is_expected.to include("start_date_fixed", "due_date_fixed", "start_date_is_fixed", "due_date_is_fixed") }
      end
    end

    describe 'related epic links' do
      let_it_be_with_reload(:target) { create(:epic, :with_synced_work_item, group: group) }
      let(:source) { epic }

      context 'when epic and work item related epic links are equal' do
        before do
          create(:related_epic_link, source: source, target: target)
          create(:work_item_link, source: source.work_item, target: target.work_item)
        end

        it { is_expected.to be_empty }
      end

      context 'when epic has links without a synced work item and work items has no links' do
        let_it_be_with_reload(:target) { create(:epic, :without_synced_work_item, group: group) }

        before do
          create(:related_epic_link, source: source, target: target)
        end

        context 'when strict_equal is false' do
          it { is_expected.to be_empty }
        end

        context 'when strict_equal is true' do
          let(:strict_equal) { true }

          it { is_expected.to include("related_links") }
        end
      end

      context 'when work item has no related link but epic has' do
        before do
          create(:related_epic_link, source: source, target: target)
        end

        it { is_expected.to include("related_links") }
      end

      context 'when eipc has no related link but the work item has' do
        before do
          create(:work_item_link, source: source.work_item, target: target.work_item)
        end

        it { is_expected.to include("related_links") }
      end
    end
  end
end
