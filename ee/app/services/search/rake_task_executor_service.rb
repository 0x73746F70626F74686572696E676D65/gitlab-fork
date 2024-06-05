# frozen_string_literal: true

module Search
  class RakeTaskExecutorService
    include ActionView::Helpers::NumberHelper

    TASKS = %i[
      enable_search_with_elasticsearch
      estimate_cluster_size
      estimate_shard_sizes
      index_epics
      index_projects
      index_projects_status
      index_snippets
      index_users
      list_pending_migrations
      mark_reindex_failed
      pause_indexing
      resume_indexing
    ].freeze

    CLASSES_TO_COUNT = Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES - [Repository, Commit, ::Wiki, WorkItem].freeze
    SHARDS_MIN = 5
    SHARDS_DIVISOR = 5_000_000
    REPOSITORY_MULTIPLIER = 0.5

    attr_reader :logger

    def initialize(logger:)
      @logger = logger
    end

    def execute(task)
      raise ArgumentError, "Unknown task: #{task}" unless TASKS.include?(task)
      raise NotImplementedError unless respond_to?(task, true)

      send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
    end

    private

    def index_snippets
      logger.info("Indexing snippets...")

      Snippet.es_import

      logger.info("Indexing snippets... #{'done'.color(:green)}")
    end

    def pause_indexing
      puts "Pausing indexing...".color(:green)

      if ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
        puts "Indexing is already paused.".color(:orange)
      else
        ::Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: true)
        puts "Indexing is now paused.".color(:green)
      end
    end

    def resume_indexing
      puts "Resuming indexing...".color(:green)

      if ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
        ::Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: false)
        puts "Indexing is now running.".color(:green)
      else
        puts "Indexing is already running.".color(:orange)
      end
    end

    def estimate_shard_sizes
      estimates = {}

      klasses = CLASSES_TO_COUNT

      unless ::Elastic::DataMigrationService.migration_has_finished?(:create_epic_index) &&
          ::Elastic::DataMigrationService.migration_has_finished?(:backfill_epics)
        klasses -= [Epic]
      end

      counts = ::Gitlab::Database::Count.approximate_counts(klasses)

      klasses.each do |klass|
        shards = (counts[klass] / SHARDS_DIVISOR) + SHARDS_MIN
        formatted_doc_count = number_with_delimiter(counts[klass], delimiter: ',')
        estimates[klass.index_name] = { document_count: formatted_doc_count, shards: shards }
      end

      sizing_url = Rails.application.routes.url_helpers
        .help_page_url('integration/advanced_search/elasticsearch', anchor: 'number-of-elasticsearch-shards')
      puts "Using approximate counts to estimate shard counts for data indexed from database. " \
           "This does not include repository data."
      puts "For single-node cluster recommendations, see #{sizing_url}"
      puts "The approximate document counts, recommended shard size, and replica size for each index are:"

      estimates.each do |index_name, estimate|
        puts "- #{index_name}:"
        puts "   document count: #{estimate[:document_count]}" if estimate.key?(:document_count)
        puts "   largest repository: #{estimate[:max_size]}" if estimate.key?(:max_size)
        puts "   largest repository size: #{estimate[:total_size]}" if estimate.key?(:total_size)
        puts "   recommended shards: #{estimate[:shards]}"
        puts "   recommended replicas: 1"
      end

      puts "Please note that it is possible to index only selected namespaces/projects by using " \
           "Advanced search indexing restrictions. This estimate does not take into account indexing " \
           "restrictions."
    end

    def estimate_cluster_size
      total_repository_size = Namespace::RootStorageStatistics.sum(:repository_size).to_i
      total_wiki_size = Namespace::RootStorageStatistics.sum(:wiki_size).to_i
      total_size = total_wiki_size + total_repository_size
      total_size_human = number_to_human_size(total_size, delimiter: ',', precision: 1, significant: false)

      estimated_cluster_size = total_size * REPOSITORY_MULTIPLIER
      estimated_cluster_size_human = number_to_human_size(estimated_cluster_size, delimiter: ',', precision: 1,
        significant: false)

      puts "This GitLab instance combined repository and wiki size is #{total_size_human}. "
      puts "By our estimates, " \
           "your cluster size should be at least #{estimated_cluster_size_human}.".color(:green)
      puts "Please note that it is possible to index only selected namespaces/projects by using " \
           "Advanced search indexing restrictions."
    end

    def mark_reindex_failed
      if ::Elastic::ReindexingTask.running?
        ::Elastic::ReindexingTask.current.failure!
        puts 'Marked the current reindexing job as failed.'.color(:green)
      else
        puts 'Did not find the current running reindexing job.'
      end
    end

    def list_pending_migrations
      pending_migrations = ::Elastic::DataMigrationService.pending_migrations

      if pending_migrations.any?
        display_pending_migrations(pending_migrations)
      else
        puts 'There are no pending migrations.'
      end
    end

    def enable_search_with_elasticsearch
      if Gitlab::CurrentSettings.elasticsearch_search?
        puts "Setting `elasticsearch_search` was already enabled."
      else
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_search: true }
        ).execute

        puts "Setting `elasticsearch_search` has been enabled."
      end
    end

    def index_projects_status
      projects = projects_maintaining_indexed_associations.size
      indexed = IndexStatus.for_project(projects_maintaining_indexed_associations).size
      percent = (indexed / projects.to_f) * 100.0

      puts format("Indexing is %.2f%% complete (%d/%d projects)", percent, indexed, projects)
    end

    def index_users
      logger.info("Indexing users...")

      User.each_batch do |users|
        ::Elastic::ProcessInitialBookkeepingService.track!(*users)
      end

      logger.info("Indexing users... #{'done'.color(:green)}")
    end

    def index_projects
      unless Gitlab::CurrentSettings.elasticsearch_indexing?
        puts "WARNING: Setting `elasticsearch_indexing` is disabled. " \
             "This setting must be enabled to enqueue projects for indexing. ".color(:yellow)
      end

      print "Enqueuing projects…"

      count = projects_in_batches do |projects|
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(*projects)
        print "."
      end

      marker = count > 0 ? "✔" : "∅"
      puts " #{marker} (#{count})"
    end

    def index_epics
      logger.info("Indexing epics...")

      groups = if ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
                 ::Gitlab::CurrentSettings.elasticsearch_limited_namespaces.where(type: "Group") # rubocop:disable CodeReuse/ActiveRecord -- This has been moved from ee/lib/tasks/gitlab/elastic.rake
               else
                 Group.all
               end

      groups.each_batch do |batch|
        ::Elastic::ProcessInitialBookkeepingService.maintain_indexed_group_associations!(*batch)
      end

      logger.info("Indexing epics... #{'done'.color(:green)}")
    end

    def display_pending_migrations(pending_migrations)
      puts "Pending Migrations".color(:yellow)
      pending_migrations.each do |migration|
        migration_info = migration.name
        migration_info << " [Obsolete]".color(:red) if migration.obsolete?
        puts migration_info
      end
    end

    def projects_maintaining_indexed_associations
      return Project.all unless ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?

      ::Gitlab::CurrentSettings.elasticsearch_limited_projects
    end

    def projects_in_batches
      count = 0
      Project.all.in_batches(start: ENV['ID_FROM'], finish: ENV['ID_TO']) do |batch| # rubocop:disable Cop/InBatches -- We need start/finish IDs here
        projects = batch.reorder(:id) # rubocop:disable CodeReuse/ActiveRecord,-- this was ported from elastic.rake

        if ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
          ::Preloaders::ProjectRootAncestorPreloader.new(projects).execute
          projects = projects.select(&:maintaining_elasticsearch?)
        end

        yield projects

        count += projects.size
      end

      count
    end
  end
end
