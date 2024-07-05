# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestOccurrences < Base
        include Gitlab::Utils::StrongMemoize

        self.model = Sbom::Occurrence
        self.unique_by = %i[uuid].freeze
        self.uses = %i[id uuid].freeze

        PIPELINE_ATTRIBUTES_KEYS = %i[pipeline_id commit_sha].freeze

        private

        def after_ingest
          each_pair do |occurrence_map, row|
            occurrence_map.occurrence_id = row.first
          end

          existing_occurrences_by_uuid.each_pair do |uuid, occurrence|
            indexed_occurrence_maps[[uuid]].each { |map| map.occurrence_id = occurrence.id }
          end
        end

        def attributes
          ensure_uuids
          occurrence_maps.uniq!(&:uuid)
          occurrence_maps.filter_map do |occurrence_map|
            uuid = occurrence_map.uuid

            new_attributes = {
              project_id: project.id,
              pipeline_id: pipeline.id,
              component_id: occurrence_map.component_id,
              component_version_id: occurrence_map.component_version_id,
              source_id: occurrence_map.source_id,
              source_package_id: occurrence_map.source_package_id,
              commit_sha: pipeline.sha,
              uuid: uuid,
              package_manager: occurrence_map.packager,
              input_file_path: occurrence_map.input_file_path,
              licenses: licenses.fetch(occurrence_map.report_component, []),
              component_name: occurrence_map.name,
              highest_severity: occurrence_map.highest_severity,
              vulnerability_count: occurrence_map.vulnerability_count,
              traversal_ids: project.namespace.traversal_ids,
              archived: project.archived,
              ancestors: occurrence_map.ancestors
            }

            if attributes_changed?(new_attributes)
              # Remove updated items from the list so that we don't have to iterate over them
              # twice when setting the ids in `after_ingest`.
              existing_occurrences_by_uuid.delete(uuid)

              new_attributes
            end
          end
        end

        def uuids
          occurrence_maps.map do |map|
            map.uuid = uuid(map)
          end
        end
        strong_memoize_attr :uuids

        alias_method :ensure_uuids, :uuids

        def existing_occurrences_by_uuid
          return {} unless uuids.present?

          Sbom::Occurrence.by_uuids(uuids).index_by(&:uuid)
        end
        strong_memoize_attr :existing_occurrences_by_uuid

        def uuid(occurrence_map)
          uuid_attributes = occurrence_map.to_h.slice(
            :component_id,
            :component_version_id,
            :source_id
          ).merge(project_id: project.id)

          ::Sbom::OccurrenceUUID.generate(**uuid_attributes)
        end

        # Return true if the new attributes differ from the existing attributes
        # for the same uuid.
        def attributes_changed?(new_attributes)
          uuid = new_attributes[:uuid]
          existing_occurrence = existing_occurrences_by_uuid[uuid]

          return true unless existing_occurrence

          compared_attributes = new_attributes.keys
          if Feature.enabled?(:skip_sbom_occurrences_update_on_pipeline_id_change, project)
            compared_attributes -= PIPELINE_ATTRIBUTES_KEYS
          end

          stable_new_attributes = new_attributes.slice(*compared_attributes)
          stable_existing_attributes = existing_occurrence.attributes.deep_symbolize_keys.slice(*compared_attributes)

          stable_new_attributes != stable_existing_attributes
        end

        def licenses
          Licenses.new(project, occurrence_maps)
        end
        strong_memoize_attr :licenses

        # This can be deleted after https://gitlab.com/gitlab-org/gitlab/-/issues/370013
        class Licenses
          include Gitlab::Utils::StrongMemoize

          attr_reader :project, :components

          def initialize(project, occurrence_maps)
            @project = project
            @components = occurrence_maps.filter_map do |occurrence_map|
              next if occurrence_map.report_component.purl.blank?

              Hashie::Mash.new(occurrence_map.to_h.slice(
                :name,
                :purl_type,
                :version
              ).merge(path: occurrence_map.input_file_path))
            end
          end

          def fetch(report_component, default = [])
            licenses.fetch(report_component.key, default)
          end

          private

          def licenses
            finder = Gitlab::LicenseScanning::PackageLicenses.new(
              components: components
            )
            finder.fetch.each_with_object({}) do |result, hash|
              licenses = result
                .fetch(:licenses, [])
                .filter_map { |license| map_from(license) }
                .sort_by { |license| license[:spdx_identifier] }
              hash[key_for(result)] = licenses if licenses.present?
            end
          end
          strong_memoize_attr :licenses

          def map_from(license)
            return if license[:spdx_identifier] == "unknown"

            license.slice(:name, :spdx_identifier, :url)
          end

          def key_for(result)
            [result.name, result.version, result.purl_type]
          end
        end
      end
    end
  end
end
