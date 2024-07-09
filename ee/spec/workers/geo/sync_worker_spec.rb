# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::SyncWorker, :geo, feature_category: :geo_replication do
  describe "#perform" do
    let(:sync_service) { instance_double(::Geo::SyncService) }

    before do
      allow(sync_service).to receive(:execute)
      allow(::Geo::SyncService).to receive(:new).with(*job_args).at_least(1).time.and_return(sync_service)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { %w[replicable_name_here 1] }

      it "calls Geo::SyncService" do
        expect(sync_service).to receive(:execute).exactly(worker_exec_times).times

        perform_idempotent_work
      end
    end
  end
end
