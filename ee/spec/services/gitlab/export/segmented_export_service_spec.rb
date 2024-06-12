# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Export::SegmentedExportService, feature_category: :shared do
  context 'when exporting a Vulnerability::Export' do
    let!(:vulnerability_export) { create(:vulnerability_export, :created) }
    let!(:vulnerability_export_parts) do
      create_list(:vulnerability_export_part, 5, vulnerability_export: vulnerability_export)
    end

    let(:segment) { nil }
    let(:segment_ids) { nil }

    let!(:export_service_mock) { instance_double(VulnerabilityExports::ExportService) }
    let(:service_object) { described_class.new(vulnerability_export) }

    before do
      allow(::Vulnerabilities::Export::Part).to receive(:where).with(id: segment_ids).and_return(
        segment
      )
      allow(vulnerability_export).to receive(:export_service).and_return(export_service_mock)

      stub_const('VulnerabilityExports::ExportService::SEGMENTED_EXPORT_WORKERS', 2)
    end

    describe '#execute' do
      let(:service_object) { described_class.new(vulnerability_export, :export, segment_ids: segment_ids) }

      context 'when exporting the first example segment' do
        let(:segment) { vulnerability_export_parts.first(3) }
        let(:segment_ids) { segment.map(&:id) }

        it 'calls the export_segment method on the desired export class for only each applicable segment' do
          segment.each do |part|
            expect(export_service_mock).to receive(:export_segment).with(part)
          end

          (vulnerability_export_parts - segment).each do |part|
            expect(export_service_mock).not_to receive(:export_segment).with(part)
          end

          service_object.execute
        end

        it 'enqueues the export finalisation' do
          allow(export_service_mock).to receive(:export_segment)
          expect(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_in).with(
            10.seconds,
            vulnerability_export.to_global_id
          )

          service_object.execute
        end
      end

      context 'when exporting the second example segment' do
        let(:segment) { vulnerability_export_parts.last(2) }
        let(:segment_ids) { segment.map(&:id) }

        it 'calls the export_segment method on the desired export class for only each applicable segment' do
          segment.each do |part|
            expect(export_service_mock).to receive(:export_segment).with(part)
          end

          (vulnerability_export_parts - segment).each do |part|
            expect(export_service_mock).not_to receive(:export_segment).with(part)
          end

          service_object.execute
        end

        it 'enqueues the export finalisation' do
          allow(export_service_mock).to receive(:export_segment)
          expect(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_in).with(
            10.seconds,
            vulnerability_export.to_global_id
          )

          service_object.execute
        end
      end
    end

    describe "when finalising" do
      let(:service_object) { described_class.new(vulnerability_export, :finalise) }

      context 'when all export parts have been exported and the export has not already been finalised' do
        before do
          vulnerability_export_parts.each do |part|
            part.update!(file: Tempfile.new)
          end
          vulnerability_export.start!
        end

        it "calls the finalise method on the desired export class" do
          expect(export_service_mock).to receive(:finalise_segmented_export)
          expect(Gitlab::Export::SegmentedExportFinalisationWorker).not_to receive(:perform_in)

          service_object.execute
        end
      end

      context 'when all export parts have been exported and the export has already been finalised' do
        before do
          vulnerability_export_parts.each do |part|
            part.update!(file: Tempfile.new)
          end
          vulnerability_export.update!(file: Tempfile.new, status: :finished)
        end

        it "does not call the finalise method on the desired export class" do
          expect(export_service_mock).not_to receive(:finalise_segmented_export)
          expect(Gitlab::Export::SegmentedExportFinalisationWorker).not_to receive(:perform_in).with(
            10.seconds,
            vulnerability_export.to_global_id
          )

          service_object.execute
        end
      end

      context 'when not all export parts have been exported' do
        before do
          vulnerability_export.update!(file: Tempfile.new, status: :running)
        end

        it "does not call the finalise method on the desired export class" do
          expect(export_service_mock).not_to receive(:finalise_segmented_export)
          expect(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_in).with(
            10.seconds,
            vulnerability_export.to_global_id
          )

          service_object.execute
        end
      end
    end
  end
end
