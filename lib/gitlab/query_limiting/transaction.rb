# frozen_string_literal: true

module Gitlab
  module QueryLimiting
    class Transaction
      THREAD_KEY = :__gitlab_query_counts_transaction

      attr_accessor :count

      # The name of the action (e.g. `UsersController#show`) that is being
      # executed.
      attr_accessor :action

      # The maximum number of SQL queries that can be executed in a request. For
      # the sake of keeping things simple we hardcode this value here, it's not
      # supposed to be changed very often anyway.
      def self.threshold
        100
      end

      def self.log_threshold
        threshold * 1.5
      end

      # Error that is raised whenever exceeding the maximum number of queries.
      ThresholdExceededError = Class.new(StandardError)

      def self.current
        Thread.current[THREAD_KEY]
      end

      # Starts a new transaction and returns it and the blocks' return value.
      #
      # Example:
      #
      #     transaction, retval = Transaction.run do
      #       10
      #     end
      #
      #     retval # => 10
      def self.run
        transaction = new
        Thread.current[THREAD_KEY] = transaction

        [transaction, yield]
      ensure
        Thread.current[THREAD_KEY] = nil
      end

      def initialize
        @action = nil
        @count = 0
        @sql_executed = []
      end

      # Sends a notification based on the number of executed SQL queries.
      def act_upon_results
        return unless threshold_exceeded?

        error = ThresholdExceededError.new(error_message)

        raise(error) if raise_error?
      end

      def increment(sql = nil)
        @count += 1 if enabled? && !ignorable?(sql)
      end

      GEO_NODES_LOAD = 'SELECT 1 AS one FROM "geo_nodes" LIMIT 1'
      LICENSES_LOAD = 'SELECT "licenses".* FROM "licenses" ORDER BY "licenses"."id"'
      ATTR_INTROSPECTION = %r/SELECT .*\ba.attname\b.* (FROM|JOIN) pg_attribute a/m.freeze

      # queries can be safely ignored if they are amoritized in regular usage
      # (i.e. only requested occasionally and otherwise cached).
      def ignorable?(sql)
        return true if sql&.include?(GEO_NODES_LOAD)
        return true if sql&.include?(LICENSES_LOAD)
        return true if ATTR_INTROSPECTION =~ sql

        false
      end

      def executed_sql(sql)
        return if @count > self.class.log_threshold || ignorable?(sql)

        @sql_executed << sql
      end

      def raise_error?
        Rails.env.test?
      end

      def threshold_exceeded?
        count > self.class.threshold
      end

      def error_message
        header = 'Too many SQL queries were executed'
        header = "#{header} in #{action}" if action
        msg = "a maximum of #{self.class.threshold} is allowed but #{count} SQL queries were executed"
        log = @sql_executed.each_with_index.map { |sql, i| "#{i}: #{sql}" }.join("\n").presence
        ellipsis = '...' if @count > self.class.log_threshold

        ["#{header}: #{msg}", log, ellipsis].compact.join("\n")
      end

      def enabled?
        ::Gitlab::QueryLimiting.enabled?
      end
    end
  end
end

Gitlab::QueryLimiting::Transaction.prepend_mod
