# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::Export::SegmentedExportService, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }

  let(:export) { create(:dependency_list_export, :running, exportable: group, project: nil) }
  let(:service_object) { described_class.new(export) }

  describe '#export_segment' do
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, traversal_ids: group.traversal_ids) }

    let(:export_part) do
      create(:dependency_list_export_part,
        dependency_list_export: export,
        start_id: sbom_occurrence.id,
        end_id: sbom_occurrence.id)
    end

    subject(:export_segment) { service_object.export_segment(export_part) }

    before_all do
      create(:sbom_occurrence, traversal_ids: group.traversal_ids)
    end

    it 'creates the file for the export part' do
      expect { export_segment }.to change { export_part.file.file }.from(nil)
    end

    it 'exports correct sbom occurrences' do
      export_segment

      exported_occurrence = Gitlab::Json.parse(export_part.file.read)

      expect(exported_occurrence).to eq({
        'name' => sbom_occurrence.component_name,
        'packager' => sbom_occurrence.package_manager,
        'version' => sbom_occurrence.version,
        'licenses' => sbom_occurrence.licenses,
        'location' => sbom_occurrence.location.stringify_keys
      })
    end

    context 'when an error happens' do
      let(:error) { RuntimeError.new }

      before do
        allow(export_part).to receive(:sbom_occurrences).and_raise(error)
        allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'marks the export as failed' do
        expect { export_segment }.to change { export.failed? }.to(true)
      end

      it 'tracks the exception and schedules export deletion worker' do
        export_segment

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_for_dev_exception).with(error)
        expect(Dependencies::DestroyExportWorker).to have_received(:perform_in).with(1.hour, export.id)
      end
    end
  end

  describe '#finalise_segmented_export' do
    subject(:finalise_export) { service_object.finalise_segmented_export }

    before do
      create_list(:dependency_list_export_part, 2, :exported, dependency_list_export: export)

      allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
    end

    it 'creates the file for the export and marks the export as finished' do
      expect { finalise_export }.to change { export.file.file }.from(nil)
                                .and change { export.finished? }.to(true)
    end

    it 'combines export parts' do
      finalise_export

      export_content = Gitlab::Json.parse(export.file.read)

      expect(export_content.length).to be(2)
    end

    it 'schedules the export deletion' do
      finalise_export

      expect(Dependencies::DestroyExportWorker).to have_received(:perform_in).with(1.hour, export.id)
    end

    context 'when an error happens' do
      let(:error) { RuntimeError.new }

      before do
        allow(export).to receive(:export_parts).and_raise(error)
        allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'marks the export as failed' do
        expect { finalise_export }.to change { export.failed? }.to(true)
      end

      it 'tracks the exception and schedules export deletion worker' do
        finalise_export

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_for_dev_exception).with(error)
        expect(Dependencies::DestroyExportWorker).to have_received(:perform_in).with(1.hour, export.id)
      end
    end
  end
end
