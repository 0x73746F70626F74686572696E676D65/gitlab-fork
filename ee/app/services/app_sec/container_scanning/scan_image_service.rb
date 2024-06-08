# frozen_string_literal: true

module AppSec
  module ContainerScanning
    class ScanImageService
      attr_reader :image, :project_id, :user_id

      SOURCE = :container_registry_push

      def initialize(image:, project_id:, user_id:)
        @image = image
        @project_id = project_id
        @user_id = user_id
      end

      def execute
        project = Project.find_by_id(project_id)
        return unless project

        if daily_limit_reached_for?(project)
          create_throttled_log_entry
          return
        end

        user = User.find_by_id(user_id)
        return unless user

        service = ::Ci::CreatePipelineService.new(project, user, ref: project.default_branch_or_main)
        service.execute(SOURCE, content: pipeline_config)
      end

      def pipeline_config
        <<~YAML
          include:
            - template: Security/Container-Scanning.gitlab-ci.yml
          container_scanning:
            stage: test
            variables:
              REGISTRY_TRIGGERED: true
              CS_IMAGE: '#{image}'
        YAML
      end

      private

      def daily_limit_reached_for?(project)
        Gitlab::ApplicationRateLimiter.throttled?(
          :container_scanning_for_registry_scans, scope: project)
      end

      def create_throttled_log_entry
        ::Gitlab::AppJsonLogger.info(
          class: self.class.name,
          project_id: project_id,
          user_id: user_id,
          image: image,
          scan_type: :container_scanning,
          pipeline_source: SOURCE,
          limit_type: :container_scanning_for_registry_scans,
          message: 'Daily rate limit container_scanning_for_registry_scans reached'
        )
      end
    end
  end
end
