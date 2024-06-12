# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Export::SegmentedExportWorker, feature_category: :shared do
  describe '#perform' do
    let(:vulnerability_export) { create(:vulnerability_export) }
    let(:global_id) { vulnerability_export.to_global_id }
    let(:export_ids) { [1, 2, 3] }
    let(:export_service_mock) { instance_double(Gitlab::Export::SegmentedExportService) }

    it 'calls SegmentedExportService#export' do
      expect(GlobalID).to receive(:find).with(global_id).and_return(vulnerability_export)
      expect(::Gitlab::Export::SegmentedExportService).to receive(:new).with(
        vulnerability_export,
        :export,
        segment_ids: export_ids
      ).and_return(export_service_mock)
      expect(export_service_mock).to receive(:execute)

      described_class.new.perform(global_id, export_ids)
    end
  end
end
