# frozen_string_literal: true

module Gitlab
  module Geo
    module GeoTasks
      extend self

      def set_primary_geo_node
        node = GeoNode.new(primary: true, name: GeoNode.current_node_name, url: GeoNode.current_node_url)
        puts "Saving primary Geo node with name #{node.name} and URL #{node.url} ..."
        node.save

        if node.persisted?
          puts "#{node.url} is now the primary Geo node".color(:green)
        else
          puts "Error saving Geo node:\n#{node.errors.full_messages.join("\n")}".color(:red)
        end
      end

      def set_secondary_as_primary
        GeoNode.transaction do
          primary_node = GeoNode.primary_node
          current_node = GeoNode.current_node

          abort 'The primary Geo site is not set' unless primary_node
          abort 'Current node is not identified' unless current_node

          if current_node.primary?
            puts "#{current_node.url} is already the primary Geo site".color(:green)
          else
            primary_node.destroy
            current_node.update!(primary: true, enabled: true)

            puts "#{current_node.url} is now the primary Geo site".color(:green)
          end
        end
      end

      def update_primary_geo_node_url
        node = Gitlab::Geo.primary_node

        unless node.present?
          puts 'This is not a primary node'.color(:red)
          exit 1
        end

        puts "Updating primary Geo node with URL #{node.url} ..."

        if node.update(name: GeoNode.current_node_name, url: GeoNode.current_node_url)
          puts "#{node.url} is now the primary Geo node URL".color(:green)
        else
          puts "Error saving Geo node:\n#{node.errors.full_messages.join("\n")}".color(:red)
          exit 1
        end
      end

      def enable_maintenance_mode
        puts 'Enabling GitLab Maintenance Mode'
        update_attrs = {
          maintenance_mode: true,
          maintenance_mode_message: ENV['MAINTENANCE_MESSAGE']
        }.compact
        ::Gitlab::CurrentSettings.update!(update_attrs)
      end

      # Note that since some non-Geo cron jobs are enabled, empty queues will be a transient state.
      # It is a sufficient check when the site is in Maintenance Mode.
      def drain_non_geo_queues
        puts 'Sidekiq Queues: Disabling all non-Geo queues'
        # TODO: Support sharded Sidekiq https://gitlab.com/gitlab-org/gitlab/-/issues/461530
        Gitlab::SidekiqSharding::Validator.allow_unrouted_sidekiq_calls do
          Sidekiq::Cron::Job.all.each(&:disable!) # rubocop:disable Rails/FindEach -- not an ActiveRecord::Relation

          # Do not enable `geo_sidekiq_cron_config_worker`, due to https://gitlab.com/gitlab-org/gitlab/-/issues/37135
          geo_primary_jobs.filter_map { |name| Sidekiq::Cron::Job.find(name) }.map(&:enable!)
        end

        puts "Sidekiq Queues: Waiting for all non-Geo queues to be empty"
        sleep(1) until all_sidekiq_queues.select { |queue| !geo_queue?(queue) && queue_has_jobs?(queue) }.empty?
        puts "Sidekiq Queues: Non-Geo queues empty".color(:green)
      end

      def wait_until_replicated_and_verified
        drain_geo_secondary_queues
        wait_for_database_replication
        wait_for_geo_log_cursor
        wait_for_data_replication_and_verification
      end

      # Note that since some Geo secondary cron jobs are enabled, empty Geo queues will be a transient state.
      # It is a sufficient check when the site is in Maintenance Mode, since we will be subsequently
      # checking for 100% replication and verification progress.
      #
      # Note that we need this check because e.g. Geo update events may be enqueued in Redis.
      def drain_geo_secondary_queues
        puts "Sidekiq Queues: Waiting for all Geo queues to be empty"
        sleep(1) until all_sidekiq_queues.select { |queue| geo_queue?(queue) && queue_has_jobs?(queue) }.empty?
        puts "Sidekiq Queues: Geo queues empty".color(:green)
      end

      # With no user activity on the primary site, we expect no new Geo update events to arrive after waiting
      # for the current DB replication lag
      def wait_for_database_replication
        puts "Database replication: Waiting for database replication to catch up"
        sleep(Gitlab::Geo::HealthCheck.new.db_replication_lag_seconds)
        puts "Database replication: Caught up".color(:green)
      end

      def wait_for_geo_log_cursor
        puts "Geo log cursor: Wait Geo log cursor to have processed all events on this secondary"
        sleep(1) until geo_log_cursor_is_caught_up?
        puts "Geo log cursor: Caught up".color(:green)
      end

      def wait_for_data_replication_and_verification
        status_check = do_status_check
        i = 0

        puts "Data replication/verification: Wait for all data to be replicated and verified"
        until status_check&.replication_verification_complete?
          status_check&.print_replication_verification_status

          sleep(1)

          # Update status
          status_check = do_status_check
          i += 1
        end
        puts "Data replication/verification: All data successfully replicated and verified".color(:green)
      end

      def do_status_check
        # Rely on Geo::MetricsUpdateWorker because:
        # 1. On large sites, it may take several minutes to produce a status
        # 2. On large sites, we do not want to run this code concurrently. GeoNodeStatus#spawn_worker will
        #    deduplicate itself if a worker is already running.
        current_node_status = GeoNodeStatus.fast_current_node_status
        return unless current_node_status

        geo_node = current_node_status.geo_node
        Gitlab::Geo::GeoNodeStatusCheck.new(current_node_status, geo_node)
      end

      def geo_log_cursor_is_caught_up?
        latest_known_id = ::Geo::EventLog.latest_event&.id
        current_cursor_id = GeoNodeStatus.new.current_cursor_last_event_id

        puts "Geo log cursor: Latest known ID: #{latest_known_id}, current cursor ID: #{current_cursor_id}"

        latest_known_id == current_cursor_id
      end

      def all_sidekiq_queues
        # TODO: Support sharded Sidekiq https://gitlab.com/gitlab-org/gitlab/-/issues/461530
        #
        # rubocop:disable Cop/SidekiqApiUsage -- For now we don't work with sharded Sidekiq
        Sidekiq::Queue.all
        # rubocop:enable Cop/SidekiqApiUsage
      end

      def geo_primary_jobs
        ::Gitlab::Geo::CronManager::COMMON_GEO_JOBS +
          ::Gitlab::Geo::CronManager::COMMON_GEO_AND_NON_GEO_JOBS +
          ::Gitlab::Geo::CronManager::PRIMARY_GEO_JOBS
      end

      def geo_queue?(queue)
        queue.name.include?('geo')
      end

      def queue_has_jobs?(queue)
        queue.size > 0 # rubocop:disable Style/ZeroLengthPredicate -- it's a Sidekiq::Queue object, not an Array
      end
    end
  end
end
