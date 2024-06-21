# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingService
      include Gitlab::Loggable

      TASKS = %i[
        dot_com_rollout
        reallocation
        remove_expired_subscriptions
        node_assignment
        mark_indices_as_ready
        initial_indexing
        auto_index_self_managed
      ].freeze

      BUFFER_FACTOR = ::Gitlab::Saas.feature_available?(:exact_code_search) ? 2 : 3
      WATERMARK_LIMIT_LOW = 0.7
      WATERMARK_LIMIT_HIGH = 0.8

      DOT_COM_ROLLOUT_TARGET_BYTES = 300.gigabytes
      DOT_COM_ROLLOUT_LIMIT = 2000
      DOT_COM_ROLLOUT_SEARCH_LIMIT = 100
      DOT_COM_ROLLOUT_ENABLE_SEARCH_AFTER = 72.hours

      attr_reader :task

      def self.execute(task)
        new(task).execute
      end

      def initialize(task)
        @task = task.to_sym
      end

      def execute
        raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.include?(task)
        raise NotImplementedError unless respond_to?(task, true)

        send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def info(task, **payload)
        logger.info(build_structured_payload(**payload.merge(task: task)))
      end

      def execute_every(period, cache_key:)
        cache_key = [self.class.name.underscore, :execute_every, cache_key].flatten.join(':')

        Gitlab::Redis::SharedState.with do |redis|
          key_set = redis.set(cache_key, 1, ex: period, nx: true)
          break false unless key_set

          yield
        end
      end

      # An initial implementation of reallocation logic. For now, it's a .com-only task
      def reallocation
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_reallocation_task)

        nodes = ::Search::Zoekt::Node.online.find_each.to_a
        over_watermark_nodes = nodes.select { |n| (n.used_bytes / n.total_bytes.to_f) >= WATERMARK_LIMIT_HIGH }

        return if over_watermark_nodes.empty?

        info(:reallocation, message: 'Detected nodes over watermark',
          watermark_limit_high: WATERMARK_LIMIT_HIGH,
          count: over_watermark_nodes.count)

        over_watermark_nodes.each do |node|
          sizes = {}

          node.indices.each_batch do |batch|
            scope = Namespace.includes(:root_storage_statistics) # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary incident mitigation task
                              .by_parent(nil)
                              .id_in(batch.select(:namespace_id))

            scope.each do |group|
              sizes[group.id] = group.root_storage_statistics&.repository_size || 0
            end
          end

          sorted = sizes.to_a.sort_by { |_k, v| v }

          namespaces_to_move = []
          total_repository_size = 0
          node_original_used_bytes = node.used_bytes
          sorted.each do |namespace_id, repository_size|
            node.used_bytes -= repository_size

            break if (node.used_bytes / node.total_bytes.to_f) < WATERMARK_LIMIT_HIGH

            namespaces_to_move << namespace_id
            total_repository_size += repository_size
          end

          unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
        end
      end

      def unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
        return if namespaces_to_move.empty?

        info(:reallocation, message: 'Unassigning namespaces from node',
          watermark_limit_high: WATERMARK_LIMIT_HIGH,
          count: namespaces_to_move.count,
          node_used_bytes: node_original_used_bytes,
          node_expected_used_bytes: node.used_bytes,
          total_repository_size: total_repository_size,
          meta: {
            "zoekt.node_name" => node.metadata['name'],
            "zoekt.node_id" => node.id
          }
        )

        namespaces_to_move.each_slice(100) do |namespace_ids|
          scope = node.indices.for_root_namespace_id(namespace_ids)

          # Mark namespaces as not searchable so that it has enough time to re-index these
          Search::Zoekt::EnabledNamespace.id_in(scope.select(:zoekt_enabled_namespace_id))
                                         .update_all(search: false, updated_at: Time.zone.now)
          scope.destroy_all # rubocop:disable Cop/DestroyAll -- we need to execute the on_destroy callbacks
        end
      end

      # A temporary task to simplify the .com Zoekt rollout
      # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary task, which will be removed after the rollout
      def dot_com_rollout
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_dot_com_rollout)
        return false if EnabledNamespace.with_missing_indices.exists?

        execute_every 2.hours, cache_key: :dot_com_rollout do
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

          if (node.used_bytes + space_required) <= node.total_bytes * WATERMARK_LIMIT_LOW
            # TODO: Once we have the task which moves pending to ready then remove the state attribute from here
            # https://gitlab.com/gitlab-org/gitlab/-/issues/439042

            zoekt_index = Search::Zoekt::Index.new(
              namespace_id: zoekt_enabled_namespace.root_namespace_id,
              zoekt_node_id: node.id,
              zoekt_enabled_namespace: zoekt_enabled_namespace,
              state: :ready,
              replica: Replica.for_enabled_namespace!(zoekt_enabled_namespace)
            )
            zoekt_indices << zoekt_index
            node.used_bytes += space_required
          else
            logger.error(build_structured_payload(
              task: :node_assignment,
              message: 'Space is not available in Node', zoekt_enabled_namespace_id: zoekt_enabled_namespace.id,
              meta: {
                "zoekt.node_name" => node.metadata['name'],
                "zoekt.node_id" => node.id
              }
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

      def mark_indices_as_ready
        initializing_indices = Search::Zoekt::Index.initializing
        if initializing_indices.empty?
          logger.info(build_structured_payload(task: :mark_indices_as_ready, message: 'Set indices ready', count: 0))
          return
        end

        count = 0
        initializing_indices.each_batch do |batch|
          records = batch.with_all_repositories_ready
          next if records.empty?

          count += records.update_all(state: :ready)
        end
        logger.info(build_structured_payload(task: :mark_indices_as_ready, message: 'Set indices ready', count: count))
      end

      def initial_indexing
        return false if Feature.disabled?(:zoekt_initial_indexing_task)

        Index.in_progress.preload_zoekt_enabled_namespace_and_namespace.preload_node.find_each do |index|
          namespace = index.zoekt_enabled_namespace&.namespace
          next unless namespace

          count = namespace.all_project_ids.count
          repo_count = index.zoekt_repositories.count
          if repo_count >= count
            index.initializing!
            node = index.node
            log_data = build_structured_payload(
              meta: {
                'zoekt.node_name' => node.metadata['name'], 'zoekt.node_id' => node.id, 'zoekt.index_id' => index.id
              },
              namespace_id: namespace.id, message: 'index moved to initializing',
              repo_count: repo_count, project_count: count, task: :initial_indexing
            )
            logger.info(log_data)
          end
        end

        Index.pending.each_batch do |batch, i|
          NamespaceInitialIndexingWorker.bulk_perform_in_with_contexts(
            i * 5.minutes, batch.preload_zoekt_enabled_namespace_and_namespace,
            arguments_proc: ->(zoekt_index) { zoekt_index.id },
            context_proc: ->(zoekt_index) { { namespace: zoekt_index.zoekt_enabled_namespace&.namespace } }
          )
        end
      end

      # This task does not need to run on .com
      def auto_index_self_managed
        return if Gitlab::Saas.feature_available?(:exact_code_search)
        return unless Gitlab::CurrentSettings.zoekt_auto_index_root_namespace?

        Namespace.group_namespaces.root_namespaces_without_zoekt_enabled_namespace.each_batch do |batch|
          data = batch.pluck_primary_key.map { |id| { root_namespace_id: id } }
          Search::Zoekt::EnabledNamespace.insert_all(data)
        end
      end
    end
  end
end
