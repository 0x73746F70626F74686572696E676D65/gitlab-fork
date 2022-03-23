# frozen_string_literal: true

module EE
  module Projects
    module PipelineHelper
      extend ::Gitlab::Utils::Override

      override :js_pipeline_tabs_data
      def js_pipeline_tabs_data(project, pipeline)
        super.merge(
          codequality_report_download_path: codequality_report_download_path(project, pipeline),
          expose_license_scanning_data: pipeline.expose_license_scanning_data?.to_json,
          expose_security_dashboard: pipeline.expose_security_dashboard?.to_json
        )
      end

      def codequality_report_download_path(project, pipeline)
        return unless project.licensed_feature_available?(:full_codequality_report)

        pipeline.downloadable_path_for_report_type(:codequality)
      end
    end
  end
end
