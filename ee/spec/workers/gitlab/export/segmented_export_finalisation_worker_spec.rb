# frozen_string_literal: true

RSpec.describe Gitlab::Export::SegmentedExportFinalisationWorker, feature_category: :shared do
  describe '#perform' do
    let(:vulnerability_export) { create(:vulnerability_export) }
    let(:global_id) { vulnerability_export.to_global_id }
    let(:export_service_mock) { instance_double(Gitlab::Export::SegmentedExportService) }

    it 'calls SegmentedExportService#export' do
      expect(GlobalID).to receive(:find).with(global_id).and_return(vulnerability_export)
      expect(::Gitlab::Export::SegmentedExportService).to receive(:new).with(vulnerability_export,
        :finalise).and_return(
          export_service_mock
        )
      expect(export_service_mock).to receive(:execute)

      described_class.new.perform(global_id)
    end
  end
end
