# frozen_string_literal: true

module SystemCheck
  module Geo
    class GeoDatabaseConfiguredCheck < SystemCheck::BaseCheck
      set_name 'GitLab Geo tracking database is correctly configured'
      set_skip_reason 'not a secondary node'

      WRONG_CONFIGURATION_MESSAGE = <<~MSG
        Rails does not appear to have the configuration necessary to connect to the Geo tracking database.
        If the tracking database is running on a node other than this one, then you may need to add configuration.
      MSG
      UNHEALTHY_CONNECTION_MESSAGE = 'Check the tracking database configuration as the connection could not be established'
      NO_TABLES_MESSAGE = 'Run the tracking database migrations: gitlab-rake db:migrate:geo'
      REUSING_EXISTING_DATABASE_MESSAGE = 'If you are reusing an existing tracking database, make sure you have reset it.'

      def skip?
        !Gitlab::Geo.secondary?
      end

      def multi_check
        unless Gitlab::Geo.geo_database_configured?
          $stdout.puts 'no'.color(:red)
          try_fixing_it(WRONG_CONFIGURATION_MESSAGE)
          for_more_information(database_docs)

          return false
        end

        unless connection_healthy?
          $stdout.puts 'no'.color(:red)
          try_fixing_it(UNHEALTHY_CONNECTION_MESSAGE)
          for_more_information(database_docs)

          return false
        end

        unless tables_present?
          $stdout.puts 'no'.color(:red)
          try_fixing_it(NO_TABLES_MESSAGE)
          for_more_information(database_docs)

          return false
        end

        unless fresh_database?
          $stdout.puts 'no'.color(:red)
          try_fixing_it(REUSING_EXISTING_DATABASE_MESSAGE)
          for_more_information(troubleshooting_docs)

          return false
        end

        $stdout.puts 'yes'.color(:green)
        true
      end

      def database_docs
        construct_help_page_url('administration/geo/setup/database')
      end

      def troubleshooting_docs
        construct_help_page_url('administration/geo/replication/troubleshooting')
      end

      private

      def connection_healthy?
        ::Geo::TrackingBase.connection.active?
      end

      def tables_present?
        !needs_migration?
      end

      def needs_migration?
        !(migrations.collect(&:version) - get_all_versions).empty?
      end

      def get_all_versions
        if schema_migration.table_exists?
          schema_migration.all_versions.map(&:to_i)
        else
          []
        end
      end

      def migrations
        ::Geo::TrackingBase.connection.migration_context.migrations
      end

      def schema_migration
        ::Geo::TrackingBase::SchemaMigration
      end

      def geo_health_check
        @geo_health_check ||= Gitlab::Geo::HealthCheck.new
      end

      def fresh_database?
        !geo_health_check.reusing_existing_tracking_database?
      end
    end
  end
end
