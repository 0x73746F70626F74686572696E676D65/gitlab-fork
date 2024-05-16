# frozen_string_literal: true

module Search
  module Zoekt
    class TaskPresenterService
      DEFAULT_LIMIT = 20
      MAX_LIMIT = 100

      attr_reader :node, :concurrency_limit

      def initialize(node)
        @node = node
        @concurrency_limit = get_concurrency_limit(node: node)
      end

      def execute
        [].tap do |payload|
          break [] if ::Gitlab::CurrentSettings.zoekt_indexing_paused?

          node.tasks.each_task(limit: concurrency_limit) do |task|
            payload << TaskSerializerService.execute(task)
          end
        end
      end

      def self.execute(...)
        new(...).execute
      end

      private

      def get_concurrency_limit(node:)
        task_count = node.metadata['task_count']
        concurrency = node.metadata['concurrency']

        return DEFAULT_LIMIT if task_count.nil? || concurrency.nil? || concurrency == 0

        (concurrency - task_count).clamp(0, MAX_LIMIT)
      end
    end
  end
end
