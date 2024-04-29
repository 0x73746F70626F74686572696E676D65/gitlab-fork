# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Task, feature_category: :global_search do
  subject(:task) { create(:zoekt_task) }

  describe 'relations' do
    it { is_expected.to belong_to(:node).inverse_of(:tasks) }
    it { is_expected.to belong_to(:zoekt_repository).inverse_of(:tasks) }
  end

  describe '.with_project' do
    it 'eager loads the zoekt_repositories and projects' do
      create(:zoekt_task)
      task = described_class.with_project.first
      recorder = ActiveRecord::QueryRecorder.new { task.zoekt_repository.project }

      expect(recorder.count).to be_zero
      expect(task.association(:zoekt_repository).loaded?).to eq(true)
    end
  end

  describe '.each_task' do
    it 'returns tasks sorted by performed_at' do
      task_1 = create(:zoekt_task, perform_at: 1.minute.ago)
      task_2 = create(:zoekt_task, perform_at: 3.minutes.ago)
      task_3 = create(:zoekt_task, perform_at: 2.minutes.ago)
      task_in_future = create(:zoekt_task, perform_at: 3.minutes.from_now)

      tasks = []
      described_class.each_task(limit: 10) do |task|
        tasks << task
      end

      expect(tasks).not_to include(task_in_future)
      expect(tasks).to eq([task_2, task_3, task_1])
    end

    context 'with orphaned task' do
      let_it_be(:orphaned_indexing_task) { create(:zoekt_task) }
      let_it_be(:orphaned_delete_task) { create(:zoekt_task, task_type: :delete_repo) }

      before do
        orphaned_indexing_task.zoekt_repository.project.destroy!
        orphaned_delete_task.zoekt_repository.project.destroy!
      end

      it 'marks indexing tasks as orphaned' do
        expect do
          described_class.each_task(limit: 10) { |t| t }
        end.to change { orphaned_indexing_task.reload.state }.from('pending').to('orphaned')
        expect(orphaned_delete_task.reload.state).to eq('pending')
      end
    end
  end

  describe 'sliding_list partitioning' do
    let(:partition_manager) { Gitlab::Database::Partitioning::PartitionManager.new(described_class) }

    describe 'next_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.next_partition_if.call(active_partition) }

      context 'when the partition is empty' do
        it { is_expected.to eq(false) }
      end

      context 'when the partition has records' do
        before do
          create(:zoekt_task, state: :pending)
          create(:zoekt_task, state: :done)
          create(:zoekt_task, state: :failed)
        end

        it { is_expected.to eq(false) }

        context 'when the first record of the partition is older than PARTITION_DURATION' do
          before do
            described_class.first.update!(created_at: (described_class::PARTITION_DURATION + 1.day).ago)
          end

          it { is_expected.to eq(true) }
        end
      end
    end

    describe 'detach_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.detach_partition_if.call(active_partition) }

      before_all do
        create(:zoekt_task, state: :pending)
        create(:zoekt_task, state: :done)
      end

      context 'when the partition contains unprocessed records' do
        it { is_expected.to eq(false) }
      end

      context 'when the partition contains only processed records' do
        before do
          described_class.update_all(state: :done)
        end

        it { is_expected.to eq(true) }
      end
    end
  end
end
