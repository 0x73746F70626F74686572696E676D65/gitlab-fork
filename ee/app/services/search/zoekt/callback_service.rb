# frozen_string_literal: true

module Search
  module Zoekt
    class CallbackService
      def initialize(node, params)
        @node = node
        @params = params.with_indifferent_access
      end

      def execute
        return unless task

        params[:success] ? process_success : process_failure
      end

      def self.execute(...)
        new(...).execute
      end

      private

      attr_reader :node, :params

      def task
        id = params.dig(:payload, :task_id)
        return unless id

        node.tasks.find_by_id(id)
      end

      def process_success
        return if task.done?

        repo = task.zoekt_repository
        ApplicationRecord.transaction do
          if task.delete_repo?
            repo&.destroy!
          else
            repo.indexed_at = Time.current
            repo.state = :ready if repo.pending? || repo.initializing?
            repo.save!
          end

          task.done!
        end
      end

      def process_failure
        return if task.failed?
        return task.update!(retries_left: task.retries_left.pred) if task.retries_left > 1

        task.update!(state: :failed, retries_left: 0)
      end
    end
  end
end
