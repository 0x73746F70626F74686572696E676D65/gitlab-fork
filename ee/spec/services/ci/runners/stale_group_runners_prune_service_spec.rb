# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::StaleGroupRunnersPruneService do
  let!(:group) { create(:group) }
  let(:service) { described_class.new }

  subject(:status) { service.perform(groups) }

  context 'with empty groups relation' do
    let!(:stale_runner) do
      create(:ci_runner, :group, groups: [group], created_at: 5.months.ago, contacted_at: 4.months.ago)
    end

    let(:groups) { Group.none }

    it 'does not prune any runners and returns :success status' do
      expect(service).not_to receive(:delete_stale_group_runners_in_batches)

      expect do
        expect(status).to match({
          status: :success,
          total_pruned: 0
        })
      end.not_to change { Ci::Runner.count }.from(1)
    end
  end

  context 'with group' do
    let!(:active_runner) do
      create(:ci_runner, :group, groups: [group], created_at: 5.months.ago, contacted_at: 10.seconds.ago)
    end

    let!(:stale_runners) do
      create_list(:ci_runner, 3, :group, groups: [group], created_at: 5.months.ago, contacted_at: 4.months.ago)
    end

    let(:group2) { create(:group) }
    let(:groups) { Group.where(id: [group.id, group2.id]) }

    before do
      stub_const("#{described_class}::GROUP_BATCH_SIZE", 1)
      stub_const("#{described_class}::BATCH_SIZE", 1)
    end

    it 'prunes all runners in batches' do
      expect(service).to receive(:delete_stale_group_runners_in_batches).twice.and_call_original

      expect do
        expect(status).to match({
          status: :success,
          total_pruned: 3
        })
      end.to change { Ci::Runner.count }.from(4).to(1)
    end
  end
end
