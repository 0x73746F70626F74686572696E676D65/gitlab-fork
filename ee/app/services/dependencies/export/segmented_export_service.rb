# frozen_string_literal: true

module Dependencies # rubocop:disable Gitlab/BoundedContexts -- This is an existing module
  module Export
    # This service class is responsible for;
    #
    # 1) Creating the partial report contents called export parts
    #    via the `export_segment` method.
    # 2) Combining the partial reports together to generate the
    #    final export via the `finalise_segmented_export` method.
    #
    # As seen this service class has multiple responsibilities but the "segmented export"
    # framework expects this interface. We will address this by a refactoring work later.
    class SegmentedExportService
      BATCH_SIZE = 1_000

      def initialize(dependency_list_export)
        @dependency_list_export = dependency_list_export
      end

      def export_segment(part)
        occurrences_iterator(part).each_batch(of: BATCH_SIZE) do |batch|
          batch.each { |occurrence| tempfile.puts json_line(occurrence) }
        end

        part.file = tempfile
        part.file.filename = segment_filename(part.start_id, part.end_id)
        part.save!
      rescue StandardError => error
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(error)

        dependency_list_export.failed!
        schedule_export_deletion
      ensure
        tempfile.close
      end

      def finalise_segmented_export
        combine_partial_export_files

        dependency_list_export.file = tempfile
        dependency_list_export.file.filename = final_export_filename
        dependency_list_export.save!
        dependency_list_export.finish!
      rescue StandardError => error
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(error)

        dependency_list_export.failed!
      ensure
        schedule_export_deletion
        tempfile.close
      end

      private

      attr_reader :dependency_list_export

      delegate :exportable, :export_parts, to: :dependency_list_export

      def occurrences_iterator(part)
        Gitlab::Pagination::Keyset::Iterator.new(
          scope: part.sbom_occurrences.order_traversal_ids_asc,
          use_union_optimization: false
        )
      end

      def tempfile
        @tempfile ||= Tempfile.new
      end

      def json_stream_writer
        @json_stream_writer ||= Oj::StreamWriter.new(tempfile, indent: 2)
      end

      def json_line(occurrence)
        {
          name: occurrence.component_name,
          packager: occurrence.package_manager,
          version: occurrence.version,
          licenses: occurrence.licenses,
          location: occurrence.location
        }.to_json
      end

      def combine_partial_export_files
        json_stream_writer.push_array

        partial_export_files.each { |part_file| write_part_to_file(part_file) }

        json_stream_writer.pop_all
      end

      def schedule_export_deletion
        Dependencies::DestroyExportWorker.perform_in(1.hour, dependency_list_export.id)
      end

      def partial_export_files
        export_parts.map(&:file)
      end

      def write_part_to_file(file)
        file.open do |stream|
          stream.each_line do |line|
            json_stream_writer.push_json(line.chomp.force_encoding(Encoding::UTF_8))
          end
        end
      end

      def final_export_filename
        [
          exportable.full_path.parameterize,
          '_dependencies_',
          Time.current.utc.strftime('%FT%H%M'),
          '.json'
        ].join
      end

      def segment_filename(start_id, end_id)
        [
          exportable.full_path.parameterize,
          "_dependencies_segment_#{start_id}_to_#{end_id}",
          Time.current.utc.strftime('%FT%H%M'),
          '.json'
        ].join
      end
    end
  end
end
