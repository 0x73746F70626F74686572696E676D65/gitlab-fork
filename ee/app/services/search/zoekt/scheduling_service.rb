# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingService
      include Gitlab::Loggable

      TASKS = %i[
        dot_com_rollout
        remove_expired_subscriptions
        node_assignment
      ].freeze

      BUFFER_FACTOR = 3
      WATERMARK_LIMIT = 0.8

      DOT_COM_ROLLOUT_TARGET_BYTES = 100.gigabytes
      DOT_COM_ROLLOUT_LIMIT = 2000
      DOT_COM_ROLLOUT_SEARCH_LIMIT = 100
      DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER = 72.hours

      attr_reader :task

      def initialize(task)
        @task = task.to_sym
      end

      def execute
        raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.include?(task)
        raise NotImplementedError unless respond_to?(task, true)

        send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
      end

      def self.execute(task)
        new(task).execute
      end

      private

      def logger
        @logger ||= ::Zoekt::Logger.build
      end

      def execute_every(period, cache_key:)
        cache_key = [self.class.name.underscore, :execute_every, cache_key].join(':')

        Gitlab::Redis::SharedState.with do |redis|
          key_set = redis.set(cache_key, 1, ex: period, nx: true)
          break false unless key_set

          yield
        end
      end

      # A temporary task to simplify the .com Zoekt rollout
      # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary task, which will be removed after the rollout
      def dot_com_rollout
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_dot_com_rollout)
        return false if EnabledNamespace.with_missing_indices.exists?

        execute_every 3.hours, cache_key: :dot_com_rollout do
          Search::Zoekt::EnabledNamespace
            .where(search: false)
            .where('created_at < ?', DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER.ago)
            .order(:id)
            .limit(DOT_COM_ROLLOUT_SEARCH_LIMIT)
            .update_all(search: true, updated_at: Time.zone.now)

          indexed_namespaces_ids = Search::Zoekt::EnabledNamespace.find_each.map(&:root_namespace_id).to_set

          sizes = {}
          GitlabSubscription.with_a_paid_hosted_plan.not_expired.each_batch(of: 100) do |batch|
            namespace_ids = batch.pluck(:namespace_id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- each_batch limits the query
            filtered_namespace_ids = namespace_ids.reject { |id| indexed_namespaces_ids.include?(id) }

            scope = Group.includes(:root_storage_statistics).where(parent_id: nil).where(id: filtered_namespace_ids)

            scope.find_each do |n|
              sizes[n.id] = n.root_storage_statistics.repository_size if n.root_storage_statistics
            end
          end

          sorted = sizes.to_a.sort_by { |_k, v| v }

          count = 0
          size = 0

          sorted.take(DOT_COM_ROLLOUT_LIMIT).each do |id, s|
            size += s
            break count if size > DOT_COM_ROLLOUT_TARGET_BYTES

            Search::Zoekt::EnabledNamespace.create!(root_namespace_id: id, search: false)
            count += 1
          end

          logger.info(build_structured_payload(
            task: :dot_com_rollout,
            message: 'Rollout has been completed',
            namespace_count: count
          ))

          count
        end
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def remove_expired_subscriptions
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)

        Search::Zoekt::EnabledNamespace.destroy_namespaces_with_expired_subscriptions!
      end

      def node_assignment
        nodes = ::Search::Zoekt::Node.online.find_each.to_a

        return false if nodes.empty?

        zoekt_indices = []

        EnabledNamespace.with_missing_indices.preload_storage_statistics.find_each do |zoekt_enabled_namespace|
          storage_statistics = zoekt_enabled_namespace.namespace.root_storage_statistics
          unless storage_statistics
            logger.error(build_structured_payload(task: :node_assignment,
              message: "RootStorageStatistics isn't available", zoekt_enabled_namespace_id: zoekt_enabled_namespace.id))
            next
          end

          space_required = BUFFER_FACTOR * storage_statistics.repository_size

          node = nodes.max_by { |n| n.total_bytes - n.used_bytes }

          if (node.used_bytes + space_required) <= node.total_bytes * WATERMARK_LIMIT
            # TODO: Once we have the task which moves pending to ready then remove the state attribute from here
            # https://gitlab.com/gitlab-org/gitlab/-/issues/439042
            zoekt_index = Search::Zoekt::Index.new(namespace_id: zoekt_enabled_namespace.root_namespace_id,
              zoekt_node_id: node.id, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)
            zoekt_indices << zoekt_index
            node.used_bytes += space_required
          else
            logger.error(build_structured_payload(
              task: :node_assignment,
              message: 'Space is not available in Node', zoekt_enabled_namespace_id: zoekt_enabled_namespace.id,
              node_id: node.id
            ))
          end
        end

        zoekt_indices.each do |zoekt_index|
          unless zoekt_index.save
            logger.error(build_structured_payload(task: :node_assignment,
              message: 'Could not save Search::Zoekt::Index', zoekt_index: zoekt_index.attributes.compact))
          end
        end
      end
    end
  end
end
