# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerManagersFinder, '#execute', feature_category: :fleet_visibility do
  subject(:runner_managers) { described_class.new(runner: runner, params: params).execute }

  let_it_be(:runner) { create(:ci_runner) }

  describe 'filter by status' do
    before_all do
      freeze_time
    end

    after :all do
      unfreeze_time
    end

    let_it_be(:offline_runner_manager) { create(:ci_runner_machine, runner: runner, contacted_at: 2.hours.ago) }
    let_it_be(:online_runner_manager) { create(:ci_runner_machine, runner: runner, contacted_at: 1.second.ago) }
    let_it_be(:never_contacted_runner_manager) { create(:ci_runner_machine, runner: runner, contacted_at: nil) }
    let_it_be(:stale_runner_manager) do
      create(
        :ci_runner_machine,
        runner: runner,
        created_at: Ci::RunnerManager.stale_deadline - 1.second,
        contacted_at: nil
      )
    end

    let(:params) { { status: status } }

    context 'for offline' do
      let(:status) { :offline }

      it { is_expected.to contain_exactly(offline_runner_manager) }
    end

    context 'for online' do
      let(:status) { :online }

      it { is_expected.to contain_exactly(online_runner_manager) }
    end

    context 'for stale' do
      let(:status) { :stale }

      it { is_expected.to contain_exactly(stale_runner_manager) }
    end

    context 'for never_contacted' do
      let(:status) { :never_contacted }

      it { is_expected.to contain_exactly(never_contacted_runner_manager, stale_runner_manager) }
    end

    context 'for invalid status' do
      let(:status) { :invalid_status }

      it 'returns all runner managers' do
        expect(runner_managers).to contain_exactly(
          offline_runner_manager, online_runner_manager, never_contacted_runner_manager, stale_runner_manager
        )
      end
    end
  end

  context 'without any filters' do
    let(:params) { {} }

    let_it_be(:runner_manager) { create(:ci_runner_machine, runner: runner) }

    it 'returns all runner managers' do
      expect(runner_managers).to contain_exactly(runner_manager)
    end
  end
end
