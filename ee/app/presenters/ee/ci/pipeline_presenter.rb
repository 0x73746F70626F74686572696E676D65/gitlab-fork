# frozen_string_literal: true

module EE
  module Ci
    module PipelinePresenter
      extend ActiveSupport::Concern

      def expose_security_dashboard?
        return false unless can?(current_user, :read_security_resource, pipeline.project)

        security_report_file_types = EE::Enums::Ci::JobArtifact.security_report_file_types
        batch_lookup_report_artifact_for_file_types(security_report_file_types.map(&:to_sym)).present?
      end

      def degradation_threshold(file_type)
        if (job_artifact = batch_lookup_report_artifact_for_file_type(file_type)) &&
            can?(current_user, :read_build, job_artifact.job)
          job_artifact.job.degradation_threshold
        end
      end
    end
  end
end
