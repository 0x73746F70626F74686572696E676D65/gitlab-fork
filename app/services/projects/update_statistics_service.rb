# frozen_string_literal: true

module Projects
  class UpdateStatisticsService < BaseService
    include ::Gitlab::Utils::StrongMemoize

    STAT_TO_CACHED_METHOD = {
      repository_size: [:size, :recent_objects_size],
      commit_count: :commit_count
    }.freeze

    def execute
      return unless project

      Gitlab::AppLogger.info("Updating statistics for project #{project.id}")

      expire_repository_caches
      expire_wiki_caches
      project.statistics.refresh!(only: statistics)

      record_onboarding_progress
    end

    private

    def expire_repository_caches
      if statistics.empty?
        project.repository.expire_statistics_caches
      elsif method_caches_to_expire.present?
        project.repository.expire_method_caches(method_caches_to_expire)
      end
    end

    def expire_wiki_caches
      return unless project.wiki_enabled? && statistics.include?(:wiki_size)

      project.wiki.repository.expire_method_caches([:size])
    end

    def method_caches_to_expire
      strong_memoize(:method_caches_to_expire) do
        statistics.flat_map { |stat| STAT_TO_CACHED_METHOD[stat] }.compact
      end
    end

    def statistics
      strong_memoize(:statistics) do
        params[:statistics]&.map(&:to_sym)
      end
    end

    def record_onboarding_progress
      return unless repository.commit_count > 1 ||
        repository.branch_count > 1 ||
        !initialized_repository_with_no_or_only_readme_file?

      Onboarding::ProgressService.new(project.namespace).execute(action: :code_added)
    end

    def initialized_repository_with_no_or_only_readme_file?
      return true if repository.empty?

      !repository.ls_files(project.default_branch).reject do |file|
        file == ::Projects::CreateService::README_FILE
      end.any?
    end
  end
end
