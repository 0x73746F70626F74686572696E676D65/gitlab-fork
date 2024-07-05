# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrences, feature_category: :dependency_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline, sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0') }

    let(:project) { pipeline.project }
    let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion) }

    subject(:ingest_occurrences) { described_class.execute(pipeline, occurrence_maps) }

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { ingest_occurrences }.to change(Sbom::Occurrence, :count).by(4)
      expect { ingest_occurrences }.not_to change(Sbom::Occurrence, :count)
    end

    describe 'attributes' do
      let(:occurrence_maps) { [occurrence_map] }
      let(:ingested_occurrence) { Sbom::Occurrence.last }
      let(:vulnerability_info) { instance_double('Sbom::Ingestion::Vulnerabilities') }
      let(:occurrence_map) do
        create(:sbom_occurrence_map, :for_occurrence_ingestion, vulnerabilities: vulnerability_info)
      end

      before do
        allow(vulnerability_info).to receive(:fetch).and_return({ vulnerability_ids: [1], highest_severity: 'high' })

        default_licenses = ["MIT", "Apache-2.0"]

        occurrence_maps.map(&:report_component).each do |component|
          create(:pm_package, name: component.name, purl_type: component.purl&.type,
            lowest_version: component.version, highest_version: component.version,
            default_license_names: default_licenses
          )
        end
      end

      it 'sets the correct attributes for the occurrence' do
        ingest_occurrences
        expect(ingested_occurrence.attributes).to include(
          'project_id' => project.id,
          'pipeline_id' => pipeline.id,
          'component_id' => occurrence_map.component_id,
          'component_version_id' => occurrence_map.component_version_id,
          'source_id' => occurrence_map.source_id,
          'commit_sha' => pipeline.sha,
          'package_manager' => occurrence_map.packager,
          'input_file_path' => occurrence_map.input_file_path,
          'source_package_id' => occurrence_map.source_package_id,
          'licenses' => [
            {
              'spdx_identifier' => 'Apache-2.0',
              'name' => 'Apache 2.0 License',
              'url' => 'https://spdx.org/licenses/Apache-2.0.html'
            },
            {
              'spdx_identifier' => 'MIT',
              'name' => 'MIT',
              'url' => 'https://spdx.org/licenses/MIT.html'
            }
          ],
          'component_name' => occurrence_map.name,
          'vulnerability_count' => 1,
          'highest_severity' => 'high',
          'traversal_ids' => project.namespace.traversal_ids,
          'archived' => project.archived,
          'ancestors' => occurrence_map.ancestors
        )
      end

      context 'when sbom occurrence was found by trivy' do
        let(:report_source) do
          build_stubbed(:ci_reports_sbom_source, data: {
            'category' => 'development',
            'image' => {
              'name' => 'docker.io/library/alpine',
              'tag' => '3.12'
            },
            'operating_system' => {
              'name' => 'Alpine',
              'version' => '3.12'
            }
          })
        end

        let(:report_component) { build_stubbed(:ci_reports_sbom_component, :with_trivy_properties) }

        let(:occurrence_map) do
          create(:sbom_occurrence_map, :for_occurrence_ingestion, report_source: report_source,
            report_component: report_component, vulnerabilities: vulnerability_info)
        end

        let(:occurrence_maps) { [occurrence_map] }

        it 'sets the correct attributes for the occurrence' do
          ingest_occurrences

          expect(ingested_occurrence.attributes).to include(
            'project_id' => project.id,
            'pipeline_id' => pipeline.id,
            'component_id' => occurrence_map.component_id,
            'component_version_id' => occurrence_map.component_version_id,
            'source_id' => occurrence_map.source_id,
            'commit_sha' => pipeline.sha,
            'package_manager' => report_component.properties.packager,
            'input_file_path' => 'container-image:docker.io/library/alpine:3.12',
            'licenses' => [
              {
                'spdx_identifier' => 'Apache-2.0',
                'name' => 'Apache 2.0 License',
                'url' => 'https://spdx.org/licenses/Apache-2.0.html'
              },
              {
                'spdx_identifier' => 'MIT',
                'name' => 'MIT',
                'url' => 'https://spdx.org/licenses/MIT.html'
              }
            ],
            'component_name' => occurrence_map.name,
            'vulnerability_count' => 1,
            'highest_severity' => 'high',
            'traversal_ids' => project.namespace.traversal_ids,
            'archived' => project.archived
          )
        end
      end
    end

    context 'when there is an existing occurrence' do
      let!(:existing_occurrence) do
        occurrence_map = occurrence_maps.first
        attributes = {
          project_id: project.id,
          pipeline_id: pipeline.id,
          component_id: occurrence_map.component_id,
          component_version_id: occurrence_map.component_version_id,
          source_id: occurrence_map.source_id,
          source_package_id: occurrence_map.source_package_id,
          commit_sha: pipeline.sha,
          licenses: [],
          component_name: occurrence_map.name,
          input_file_path: occurrence_map.input_file_path,
          highest_severity: occurrence_map.highest_severity,
          vulnerability_count: occurrence_map.vulnerability_count,
          traversal_ids: project.namespace.traversal_ids,
          archived: project.archived,
          ancestors: occurrence_map.ancestors
        }

        create(:sbom_occurrence, **attributes)
      end

      it 'does not create a new record for the existing version' do
        expect { ingest_occurrences }.to change(Sbom::Occurrence, :count).by(3)
        expect(occurrence_maps.map(&:occurrence_id)).to match_array([Integer, Integer, Integer, existing_occurrence.id])
      end

      context 'when only attributes related to the pipeline have been changed' do
        let_it_be(:other_pipeline) do
          create(:ci_pipeline, sha: '5716ca5987cbf97d6bb54920bea6adde242d87e6', project: pipeline.project)
        end

        before do
          existing_occurrence.update!(pipeline: other_pipeline, commit_sha: other_pipeline.sha)
        end

        it 'does not update existing records' do
          expect { ingest_occurrences }.not_to change { existing_occurrence.reload.updated_at }
        end

        context 'when skip_sbom_occurrences_update_on_pipeline_id_change is disabled' do
          before do
            stub_feature_flags(skip_sbom_occurrences_update_on_pipeline_id_change: false)
          end

          it 'updates existing existing records' do
            expect { ingest_occurrences }.to change { existing_occurrence.reload.updated_at }
          end
        end
      end

      context 'when attributes not related to the pipeline have been changed' do
        let_it_be(:other_project) { create(:project) }

        before do
          existing_occurrence.update!(project: other_project, traversal_ids: other_project.namespace.traversal_ids)
        end

        it 'updates the record' do
          expect { ingest_occurrences }.to change { existing_occurrence.reload.project }.from(other_project).to(project)
            .and change { existing_occurrence.reload.traversal_ids }
            .from(other_project.namespace.traversal_ids).to(project.namespace.traversal_ids)
        end
      end
    end

    context 'when there is no component version' do
      let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion, component_version: nil) }

      it 'inserts records without the version' do
        expect { ingest_occurrences }.to change(Sbom::Occurrence, :count).by(4)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end

      it 'does not include licenses' do
        ingest_occurrences

        expect(Sbom::Occurrence.pluck(:licenses)).to all(be_empty)
      end
    end

    context 'when there is no source package' do
      let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4, :for_occurrence_ingestion, source_package: nil) }

      it 'inserts records without the source package' do
        expect { ingest_occurrences }.to change(Sbom::Occurrence, :count).by(4)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end
    end

    context 'when there is no purl' do
      let(:component) { create(:ci_reports_sbom_component, purl: nil) }
      let(:occurrence_map) { create(:sbom_occurrence_map, :for_occurrence_ingestion, report_component: component) }
      let(:occurrence_maps) { [occurrence_map] }

      it 'skips licenses for components without a purl' do
        expect { ingest_occurrences }.to change(Sbom::Occurrence, :count).by(1)

        expect(Sbom::Occurrence.pluck(:licenses)).to all(be_empty)
      end
    end

    context 'when there are two duplicate occurrences' do
      let(:occurrence_maps) do
        map1 = create(:sbom_occurrence_map, :for_occurrence_ingestion)
        map2 = create(:sbom_occurrence_map)
        map2.component_id = map1.component_id
        map2.component_version_id = map1.component_version_id
        map2.source_id = map1.source_id

        [map1, map2]
      end

      it 'discards duplicates' do
        expect { ingest_occurrences }.to change { ::Sbom::Occurrence.count }.by(1)
        expect(occurrence_maps.size).to eq(1)
        expect(occurrence_maps).to all(have_attributes(occurrence_id: Integer))
      end
    end
  end
end
