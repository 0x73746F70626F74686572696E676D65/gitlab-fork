# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::EventWorker, :geo, feature_category: :geo_replication do
  describe "#perform" do
    let(:event_service) { instance_double(::Geo::EventService) }

    before do
      allow(event_service).to receive(:execute)
      allow(::Geo::EventService).to receive(:new).with(*job_args).at_least(1).time.and_return(event_service)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { ["package_file", "created", { "model_record_id" => 1 }] }

      it "calls Geo::EventService" do
        expect(event_service).to receive(:execute).exactly(worker_exec_times).times

        perform_idempotent_work
      end
    end
  end
end
