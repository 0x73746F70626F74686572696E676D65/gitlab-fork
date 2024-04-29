# frozen_string_literal: true

module Search
  module Zoekt
    class TaskSerializerService
      INDEXING_TIMEOUT_S = 30.minutes.to_i

      attr_reader :task

      def initialize(task)
        @task = task
      end

      def execute
        case task.task_type.to_sym
        when :index_repo
          {
            name: :index,
            payload: index_repo_payload
          }
        when :force_index_repo
          {
            name: :index,
            payload: force_index_repo_payload
          }
        when :delete_repo
          {
            name: :delete,
            payload: delete_repo_payload
          }
        else
          raise ArgumentError, "Unknown task_type: #{task.task_type.inspect}"
        end
      end

      def self.execute(...)
        new(...).execute
      end

      private

      def index_repo_payload
        project = task.zoekt_repository.project
        repository_storage = project.repository_storage
        connection_info = Gitlab::GitalyClient.connection_data(repository_storage)
        repository_path = "#{project.repository.disk_path}.git"
        address = connection_info['address']

        # This code is needed to support relative unix: connection strings. For example, specs
        if address.match?(%r{\Aunix:[^/.]})
          path = address.split('unix:').last
          address = "unix:#{Rails.root.join(path)}"
        end

        {
          GitalyConnectionInfo: {
            Address: address,
            Token: connection_info['token'],
            Storage: repository_storage,
            Path: repository_path
          },
          Callback: { name: 'index', payload: { task_id: task.id } },
          RepoId: project.id,
          FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
          Timeout: "#{INDEXING_TIMEOUT_S}s"
        }
      end

      def force_index_repo_payload
        index_repo_payload.merge(Force: true)
      end

      def delete_repo_payload
        {
          RepoId: task.project_identifier,
          Callback: { name: 'delete', payload: { task_id: task.id } }
        }
      end
    end
  end
end
