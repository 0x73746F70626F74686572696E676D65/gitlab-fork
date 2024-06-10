# frozen_string_literal: true

module Search
  class RakeTaskExecutorService
    include ActionView::Helpers::NumberHelper

    TASKS = %i[
      clear_index_status
      create_empty_index
      delete_index
      disable_search_with_elasticsearch
      enable_search_with_elasticsearch
      estimate_cluster_size
      estimate_shard_sizes
      index_epics
      index_group_entities
      index_group_wikis
      index_namespaces
      index_projects
      index_projects_status
      index_snippets
      index_users
      info
      list_pending_migrations
      mark_reindex_failed
      pause_indexing
      projects_not_indexed
      recreate_index
      reindex_cluster
      resume_indexing
    ].freeze

    CLASSES_TO_COUNT = Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES - [Repository, Commit, ::Wiki, WorkItem].freeze
    SHARDS_MIN = 5
    SHARDS_DIVISOR = 5_000_000
    REPOSITORY_MULTIPLIER = 0.5
    MAX_PROJECTS_TO_DISPLAY = 500

    def initialize(logger:)
      @logger = logger
    end

    def execute(task)
      raise ArgumentError, "Unknown task: #{task}" unless TASKS.include?(task)
      raise NotImplementedError unless respond_to?(task, true)

      send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
    end

    private

    attr_reader :logger

    def clear_index_status
      IndexStatus.delete_all
      ::Elastic::GroupIndexStatus.delete_all
      logger.info('Index status has been reset'.color(:green))
    end

    def create_empty_index
      with_alias = ENV['SKIP_ALIAS'].nil?
      options = {}

      index_name = helper.create_empty_index(with_alias: with_alias, options: options)

      # with_alias is used to support interacting with a specific index (such as when reclaiming the production index
      # name when the index was created prior to 13.0). If the `SKIP_ALIAS` environment variable is set,
      # do not create standalone indexes and do not create the migrations index
      if with_alias
        standalone_index_names = helper.create_standalone_indices(options: options)
        standalone_index_names.each do |index_name, alias_name|
          logger.info("Index '#{index_name}' has been created.".color(:green))
          logger.info("Alias '#{alias_name}' -> '#{index_name}' has been created.".color(:green))
        end

        helper.create_migrations_index unless helper.migrations_index_exists?
        ::Elastic::DataMigrationService.mark_all_as_completed!
      end

      logger.info("Index '#{index_name}' has been created.".color(:green))
      logger.info("Alias '#{helper.target_name}' → '#{index_name}' has been created".color(:green)) if with_alias
    end

    def delete_index
      if helper.delete_index
        logger.info("Index/alias '#{helper.target_name}' has been deleted".color(:green))
      else
        logger.info("Index/alias '#{helper.target_name}' was not found".color(:green))
      end

      results = helper.delete_standalone_indices
      results.each do |index_name, alias_name, result|
        if result
          logger.info("Index '#{index_name}' with alias '#{alias_name}' has been deleted".color(:green))
        else
          logger.info("Index '#{index_name}' with alias '#{alias_name}' was not found".color(:green))
        end
      end

      if helper.delete_migrations_index
        logger.info("Index/alias '#{helper.migrations_index_name}' has been deleted".color(:green))
      else
        logger.info("Index/alias '#{helper.migrations_index_name}' was not found".color(:green))
      end
    end

    def recreate_index
      delete_index
      create_empty_index
    end

    def reindex_cluster
      ::Elastic::ReindexingTask.create!

      ::ElasticClusterReindexingCronWorker.perform_async

      logger.info('Reindexing job was successfully scheduled'.color(:green))
    rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
      logger.error('There is another task in progress. Please wait for it to finish.'.color(:red))
    end

    def index_snippets
      logger.info('Indexing snippets...')

      Snippet.es_import

      logger.info("Indexing snippets... #{'done'.color(:green)}")
    end

    def pause_indexing
      logger.info('Pausing indexing...'.color(:green))

      if ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
        logger.info('Indexing is already paused.'.color(:orange))
      else
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_pause_indexing: true }
        ).execute

        logger.info('Indexing is now paused.'.color(:green))
      end
    end

    def resume_indexing
      logger.info('Resuming indexing...'.color(:green))

      if ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_pause_indexing: false }
        ).execute

        logger.info('Indexing is now running.'.color(:green))
      else
        logger.info('Indexing is already running.'.color(:orange))
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
      logger.info('Using approximate counts to estimate shard counts for data indexed from database. ' \
        "This does not include repository data. For single-node cluster recommendations, see #{sizing_url}.\n" \
        'The approximate document counts, recommended shard size, and replica size for each index are:')

      estimates.each do |index_name, estimate|
        estimate = <<~ESTIMATE
          - #{index_name}:
            document count: #{estimate[:document_count]}
            recommended shards: #{estimate[:shards]}
            recommended replicas: 1
        ESTIMATE

        logger.info(estimate)
      end

      logger.info('Please note that it is possible to index only selected namespaces/projects by using ' \
        'Advanced search indexing restrictions. This estimate does not take into account indexing ' \
        'restrictions.')
    end

    def estimate_cluster_size
      total_repository_size = Namespace::RootStorageStatistics.sum(:repository_size).to_i
      total_wiki_size = Namespace::RootStorageStatistics.sum(:wiki_size).to_i
      total_size = total_wiki_size + total_repository_size
      total_size_human = number_to_human_size(total_size, delimiter: ',', precision: 1, significant: false)

      estimated_cluster_size = total_size * REPOSITORY_MULTIPLIER
      estimated_cluster_size_human = number_to_human_size(estimated_cluster_size, delimiter: ',', precision: 1,
        significant: false)

      logger.info("This GitLab instance combined repository and wiki size is #{total_size_human}. ")
      logger.info('By our estimates, ' \
        "your cluster size should be at least #{estimated_cluster_size_human}. ".color(:green))
      logger.info('Please note that it is possible to index only selected namespaces/projects by using ' \
        'Advanced search indexing restrictions.')
    end

    def mark_reindex_failed
      if ::Elastic::ReindexingTask.running?
        ::Elastic::ReindexingTask.current.failure!
        logger.info('Marked the current reindexing job as failed.'.color(:green))
      else
        logger.info('Did not find the current running reindexing job.')
      end
    end

    def projects_not_indexed
      not_indexed = []

      ::Search::ElasticProjectsNotIndexedFinder.execute.each_batch do |batch|
        batch.inc_routes.each do |project|
          not_indexed << project
        end
      end

      if not_indexed.empty?
        logger.info('All projects are currently indexed'.color(:green))
      else
        display_unindexed(not_indexed)
      end
    end

    def display_unindexed(projects)
      arr = if projects.count < MAX_PROJECTS_TO_DISPLAY || ENV['SHOW_ALL']
              projects
            else
              projects[1..MAX_PROJECTS_TO_DISPLAY]
            end

      arr.each { |p| logger.warn("Project '#{p.full_path}' (ID: #{p.id}) isn't indexed.".color(:red)) }

      logger.info("#{arr.count} out of #{projects.count} non-indexed projects shown.")
    end

    def list_pending_migrations
      pending_migrations = ::Elastic::DataMigrationService.pending_migrations

      if pending_migrations.any?
        display_pending_migrations(pending_migrations)
      else
        logger.info('There are no pending migrations.')
      end
    end

    def enable_search_with_elasticsearch
      if Gitlab::CurrentSettings.elasticsearch_search?
        logger.info('Setting `elasticsearch_search` was already enabled.')
      else
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_search: true }
        ).execute

        logger.info('Setting `elasticsearch_search` has been enabled.')
      end
    end

    def disable_search_with_elasticsearch
      if Gitlab::CurrentSettings.elasticsearch_search?
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_search: false }
        ).execute

        logger.info('Setting `elasticsearch_search` has been disabled.')
      else
        logger.info('Setting `elasticsearch_search` was already disabled.')
      end
    end

    def index_projects_status
      projects = projects_maintaining_indexed_associations.size
      indexed = IndexStatus.for_project(projects_maintaining_indexed_associations).size
      percent = (indexed / projects.to_f) * 100.0

      logger.info(format('Indexing is %.2f%% complete (%d/%d projects)', percent, indexed, projects))
    end

    def index_users
      logger.info('Indexing users...')

      User.each_batch do |users|
        ::Elastic::ProcessInitialBookkeepingService.track!(*users)
      end

      logger.info("Indexing users... #{'done'.color(:green)}")
    end

    def index_namespaces
      Namespace.by_parent(nil).each_batch do |batch|
        batch = batch.include_route
        batch = batch.select(&:use_elasticsearch?)

        ElasticNamespaceIndexerWorker.bulk_perform_async_with_contexts(
          batch,
          arguments_proc: ->(namespace) { [namespace.id, :index] },
          context_proc: ->(namespace) { { namespace: namespace } }
        )
      end
    end

    def index_projects
      unless Gitlab::CurrentSettings.elasticsearch_indexing?
        logger.warn('WARNING: Setting `elasticsearch_indexing` is disabled. ' \
          'This setting must be enabled to enqueue projects for indexing. '.color(:yellow))
      end

      logger.info('Enqueuing projects...')

      count = projects_in_batches do |projects|
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(*projects)
        print '.' # do not send to structured log
      end

      marker = count > 0 ? "✔" : "∅"
      logger.info(" #{marker} (#{count})")
    end

    def index_epics
      logger.info('Indexing epics...')

      groups = if ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
                 ::Gitlab::CurrentSettings.elasticsearch_limited_namespaces.group_namespaces
               else
                 Group.all
               end

      groups.each_batch do |batch|
        ::Elastic::ProcessInitialBookkeepingService.maintain_indexed_group_associations!(*batch)
      end

      logger.info("Indexing epics... #{'done'.color(:green)}")
    end

    def index_group_entities
      raise 'This task cannot be run on GitLab.com' if ::Gitlab::Saas.feature_available?(:advanced_search)

      logger.info('Enqueuing Group level entities…')
      index_epics
      index_group_wikis
    end

    def index_group_wikis
      raise 'This task cannot be run on GitLab.com' if ::Gitlab::Saas.feature_available?(:advanced_search)

      logger.info('Indexing group wikis...')

      groups_with_wiki_repos = if Gitlab::CurrentSettings.elasticsearch_limit_indexing?
                                 Gitlab::CurrentSettings.elasticsearch_limited_namespaces
                                   .group_namespaces.with_group_wiki_repositories
                               else
                                 GroupWikiRepository.all
                               end

      groups_with_wiki_repos.each_batch do |batch|
        group_ids = batch.pluck_primary_key
        group_ids.each { |group_id| ::ElasticWikiIndexerWorker.perform_async(group_id, 'Group', force: true) }
      end

      logger.info("Indexing group wikis... #{'done'.color(:green)}")
    end

    def info
      setting = ::ApplicationSetting.current

      logger.info("\nAdvanced Search".color(:yellow))
      logger.info("Server version:\t\t\t" \
        "#{helper.server_info[:version] || 'unknown'.color(:red)}")
      logger.info("Server distribution:\t\t" \
        "#{helper.server_info[:distribution] || 'unknown'.color(:red)}")
      logger.info("Indexing enabled:\t\t#{setting.elasticsearch_indexing? ? 'yes'.color(:green) : 'no'}")
      logger.info("Search enabled:\t\t\t#{setting.elasticsearch_search? ? 'yes'.color(:green) : 'no'}")
      logger.info("Requeue Indexing workers:\t" \
        "#{setting.elasticsearch_requeue_workers? ? 'yes'.color(:green) : 'no'}")
      logger.info("Pause indexing:\t\t\t" \
        "#{setting.elasticsearch_pause_indexing? ? 'yes'.color(:green) : 'no'}")
      logger.info("Indexing restrictions enabled:\t" \
        "#{setting.elasticsearch_limit_indexing? ? 'yes'.color(:yellow) : 'no'}")
      logger.info("File size limit:\t\t#{setting.elasticsearch_indexed_file_size_limit_kb} KiB")
      logger.info("Indexing number of shards:\t" \
        "#{::Elastic::ProcessBookkeepingService.active_number_of_shards}")
      logger.info("Max code indexing concurrency:\t" \
        "#{setting.elasticsearch_max_code_indexing_concurrency}")

      display_indexing_queues

      check_handler do
        pending_migrations = ::Elastic::DataMigrationService.pending_migrations

        display_pending_migrations(pending_migrations) if pending_migrations.any?
      end

      check_handler do
        display_current_migration
      end

      display_index_settings
    end

    def check_handler
      yield
    rescue StandardError => e
      logger.error("An exception occurred during the retrieval of the data: #{e.class}: #{e.message}".color(:red))
    end

    def display_current_migration
      current_migration = ::Elastic::MigrationRecord.current_migration
      return unless current_migration

      current_state = current_migration.load_state

      logger.info("\nCurrent Migration".color(:yellow))
      logger.info("Name:\t\t\t#{current_migration.name}")
      logger.info("Started:\t\t#{current_migration.started? ? 'yes'.color(:green) : 'no'}")
      logger.info("Halted:\t\t\t#{current_migration.halted? ? 'yes'.color(:red) : 'no'.color(:green)}")
      logger.info("Failed:\t\t\t#{current_migration.failed? ? 'yes'.color(:red) : 'no'.color(:green)}")
      logger.info("Obsolete:\t\t#{current_migration.obsolete? ? 'yes'.color(:red) : 'no'.color(:green)}")
      logger.info("Current state:\t\t#{current_state.to_json}") if current_state.present?
    end

    def display_indexing_queues
      logger.info("\nIndexing Queues".color(:yellow))
      logger.info("Initial queue:\t\t\t#{::Elastic::ProcessInitialBookkeepingService.queue_size}")
      logger.info("Incremental queue:\t\t#{::Elastic::ProcessBookkeepingService.queue_size}")
    end

    def display_index_settings
      logger.info("\nIndices".color(:yellow))
      indices = ::Elastic::IndexSetting.order_by_name.pluck(:alias_name) # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- table contains small dataset
      indices.each do |alias_name|
        index_setting = {}

        begin
          index_setting = helper.client.indices.get_settings(index: alias_name).with_indifferent_access
          document_count = helper.documents_count(index_name: alias_name)
        rescue StandardError
          logger.error("  - failed to load indices for #{alias_name}".color(:red))
        end

        index_setting.sort.each do |index_name, hash|
          logger.info("- #{index_name}:")
          logger.info("\tdocument_count: #{document_count}")
          logger.info("\tnumber_of_shards: #{hash.dig('settings', 'index', 'number_of_shards')}")
          logger.info("\tnumber_of_replicas: #{hash.dig('settings', 'index', 'number_of_replicas')}")
          refresh_interval = hash.dig('settings', 'index', 'refresh_interval')
          logger.info("\trefresh_interval: #{refresh_interval}") if refresh_interval
          (hash.dig('settings', 'index', 'blocks') || {}).each do |block, value|
            next unless value == 'true'

            logger.error("\tblocks.#{block}: yes".color(:red))
          end
        end
      end
    end

    def display_pending_migrations(pending_migrations)
      logger.info('Pending Migrations'.color(:yellow))
      pending_migrations.each do |migration|
        migration_info = migration.name
        if migration.obsolete?
          migration_info << ' [Obsolete]'.color(:red)
          logger.warn(migration_info)
        else
          logger.info(migration_info)
        end
      end
    end

    def projects_maintaining_indexed_associations
      return Project.all unless ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?

      ::Gitlab::CurrentSettings.elasticsearch_limited_projects
    end

    def projects_in_batches
      count = 0
      Project.all.in_batches(start: ENV['ID_FROM'], finish: ENV['ID_TO']) do |batch| # rubocop:disable Cop/InBatches -- We need start/finish IDs here
        projects = batch.projects_order_id_asc

        if ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
          ::Preloaders::ProjectRootAncestorPreloader.new(projects).execute
          projects = projects.select(&:maintaining_elasticsearch?)
        end

        yield projects

        count += projects.size
      end

      count
    end

    def helper
      @helper ||= ::Gitlab::Elastic::Helper.default
    end
  end
end
