# frozen_string_literal: true

# This service is a generalized mechanic for orchestrating large exports
# without risk of race conditions resulting in double exporting of the same
# part.
#
# When the export is completed, a finalisation step can be called separately.

module Gitlab
  module Export
    class SegmentedExportService
      def initialize(export, operation, args = {})
        @export = export
        @operation = operation
        @args = args
      end

      def execute
        case @operation
        when :export
          export(@args[:segment_ids])
        when :finalise
          finalise
        end
      end

      private

      def export(segment_ids)
        export_parts = export_part_class.id_in(segment_ids)

        export_parts.each { |export_part| @export.export_service.export_segment(export_part) }

        Gitlab::Export::SegmentedExportFinalisationWorker.perform_in(10.seconds, @export.to_global_id)
      end

      def finalise
        if all_export_parts_present? && @export.running?
          @export.export_service.finalise_segmented_export
        elsif @export.running?
          Gitlab::Export::SegmentedExportFinalisationWorker.perform_in(10.seconds, @export.to_global_id)
        end
      end

      def export_part_class
        @export.class::Part
      end

      def all_export_parts_present?
        @export.export_parts.all? { |part| part.file.present? }
      end
    end
  end
end
