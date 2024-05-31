# frozen_string_literal: true

module AppSec
  module ContainerScanning
    class ScanImageService
      attr_reader :image, :project_id, :user_id

      def initialize(image:, project_id:, user_id:)
        @image = image
        @project_id = project_id
        @user_id = user_id
      end

      def execute
        project = Project.find_by_id(project_id)
        return unless project

        return if daily_limit_reached_for?(project)

        user = User.find_by_id(user_id)
        return unless user

        service = ::Ci::CreatePipelineService.new(project, user, ref: project.default_branch_or_main)
        service.execute(:container_registry_push, content: pipeline_config)
      end

      def pipeline_config
        <<~YAML
          include:
            - template: Security/Container-Scanning.gitlab-ci.yml
          container_scanning:
            stage: test
            variables:
              SECURE_LOG_LEVEL: debug
              REGISTRY_TRIGGERED: true
              CS_DISABLE_DEPENDENCY_LIST: true
              CS_IMAGE: '#{image}'
        YAML
      end

      private

      def daily_limit_reached_for?(project)
        Gitlab::ApplicationRateLimiter.throttled?(
          :container_scanning_for_registry_scans, scope: project)
      end
    end
  end
end
