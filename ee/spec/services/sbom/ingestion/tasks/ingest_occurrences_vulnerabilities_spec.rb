# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrencesVulnerabilities, feature_category: :dependency_management do
  describe '#execute' do
    let_it_be(:pipeline) { build(:ci_pipeline) }

    let!(:finding_1) do
      create(
        :vulnerabilities_finding,
        :detected,
        :with_dependency_scanning_metadata,
        project: pipeline.project,
        file: occurrence_map_1.input_file_path,
        package: occurrence_map_1.name,
        version: occurrence_map_1.version,
        pipeline: pipeline
      )
    end

    let!(:finding_2) do
      create(
        :vulnerabilities_finding,
        :detected,
        :with_dependency_scanning_metadata,
        project: pipeline.project,
        file: occurrence_map_2.input_file_path,
        package: occurrence_map_2.name,
        version: occurrence_map_2.version,
        pipeline: pipeline
      )
    end

    let(:occurrence_map_1) do
      create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence, vulnerabilities: vulnerability_info)
    end

    let(:occurrence_map_2) do
      create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence, vulnerabilities: vulnerability_info)
    end

    let(:occurrence_maps) { [occurrence_map_1, occurrence_map_2] }
    let(:vulnerability_info) { create(:sbom_vulnerabilities, pipeline: pipeline) }

    subject(:ingest_occurrences_vulnerabilities) do
      described_class.execute(pipeline, occurrence_maps)
    end

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { described_class.execute(pipeline, occurrence_maps) }
        .to change { Sbom::OccurrencesVulnerability.count }.by(2)
      expect { described_class.execute(pipeline, occurrence_maps) }
        .not_to change { Sbom::OccurrencesVulnerability.count }
    end

    describe 'attributes' do
      it 'sets the correct attributes for the occurrence' do
        ingest_occurrences_vulnerabilities

        expect(Sbom::OccurrencesVulnerability.all).to match_array([
          an_object_having_attributes('sbom_occurrence_id' => occurrence_map_2.occurrence_id,
            'vulnerability_id' => finding_2.vulnerability_id),
          an_object_having_attributes('sbom_occurrence_id' => occurrence_map_1.occurrence_id,
            'vulnerability_id' => finding_1.vulnerability_id)
        ])
      end
    end

    context 'when there is an existing occurrence' do
      before do
        create(:sbom_occurrences_vulnerability,
          sbom_occurrence_id: occurrence_map_1.occurrence_id,
          vulnerability_id: finding_1.vulnerability_id)
      end

      it 'does not create a new record for the existing occurrence' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(1)
      end
    end

    context 'when there is more than one vulnerability per occurrence' do
      before do
        create(
          :vulnerabilities_finding,
          :detected,
          :with_dependency_scanning_metadata,
          project: pipeline.project,
          file: occurrence_map_1.input_file_path,
          package: occurrence_map_1.name,
          version: occurrence_map_1.version,
          pipeline: pipeline
        )
      end

      it 'creates all related occurrences_vulnerabilities' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(3)
      end
    end

    context 'when there is no vulnerabilities' do
      let(:occurrence_map_3) { create(:sbom_occurrence_map, :for_occurrence_ingestion, :with_occurrence) }
      let(:occurrence_maps) { [occurrence_map_1, occurrence_map_2, occurrence_map_3] }

      it 'skips records without vulnerabilities' do
        expect { ingest_occurrences_vulnerabilities }.to change { Sbom::OccurrencesVulnerability.count }.by(2)
      end
    end
  end
end
