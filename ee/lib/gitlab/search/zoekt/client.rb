# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Client # rubocop:disable Search/NamespacedClass
        include Gitlab::Utils::StrongMemoize
        INDEXING_TIMEOUT_S = 30.minutes.to_i

        class << self
          def instance
            @instance ||= new
          end

          delegate :search, :index, :delete, :truncate, to: :instance
        end

        def search(query, num:, project_ids:, shard_id:)
          start = Time.current

          payload = {
            Q: query,
            Opts: {
              TotalMaxMatchCount: num,
              NumContextLines: 1
            }
          }

          # Safety net because Zoekt will match all projects if you provide
          # an empty array.
          raise 'Not possible to search without at least one project specified' if project_ids.blank?
          raise 'Global search is not supported' if project_ids == :any

          payload[:RepoIDs] = project_ids
          path = '/api/search'
          target_shard = shard(shard_id)
          raise 'Shard can not be found' unless target_shard

          response = post(
            URI.join(target_shard.search_base_url, path),
            payload,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          )

          unless response.success?
            logger.error(message: 'Zoekt search failed', status: response.code, response: response.body)
          end

          ::Gitlab::Json.parse(response.body, symbolize_names: true)
        ensure
          add_request_details(start_time: start, path: path, body: payload)
        end

        def index(project, shard_id)
          return index_with_new_indexer(project, shard_id) if use_new_zoekt_indexer?

          index_with_legacy_indexer(project, shard_id)
        end

        def delete(shard_id:, project_id:)
          return false unless use_new_zoekt_indexer?

          target_shard = shard(shard_id)
          raise 'Shard can not be found' unless target_shard

          response = delete_request(URI.join(target_shard.index_base_url, "/indexer/index/#{project_id}"))

          raise "Request failed with: #{response.inspect}" unless response.success?
          raise response['Error'] if response['Error']

          response
        end

        def truncate
          ::Zoekt::Shard.find_each { |shard| post(URI.join(shard.index_base_url, zoekt_indexer_truncate_path)) }
        end

        private

        def post(url, payload = {}, **options)
          defaults = {
            headers: { "Content-Type" => "application/json" },
            body: payload.to_json,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.post(
            url,
            defaults.merge(options)
          )
        end

        def delete_request(url, **options)
          defaults = {
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.delete(
            url,
            defaults.merge(options)
          )
        end

        def zoekt_indexer_post(path, payload, shard_id)
          target_shard = shard(shard_id)
          raise 'Shard can not be found' unless target_shard

          post(
            URI.join(target_shard.index_base_url, path),
            payload,
            timeout: INDEXING_TIMEOUT_S
          )
        end

        def basic_auth_params
          @basic_auth_params ||= {
            username: username,
            password: password
          }.compact
        end

        def index_with_legacy_indexer(project, shard_id)
          payload = { CloneUrl: project.http_url_to_repo, RepoId: project.id }

          response = zoekt_indexer_post('/index', payload, shard_id)

          raise response['Error'] if response['Error']

          response
        end

        def index_with_new_indexer(project, shard_id)
          response = zoekt_indexer_post('/indexer/index', indexing_payload(project), shard_id)

          raise response['Error'] if response['Error']
          raise "Request failed with: #{response.inspect}" unless response.success?

          response
        end

        def indexing_payload(project)
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
            RepoId: project.id,
            FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
            Timeout: "#{INDEXING_TIMEOUT_S}s"
          }
        end

        def shard(shard_id)
          strong_memoize(:shard) do
            ::Zoekt::Shard.find_by_id(shard_id)
          end
        end

        def add_request_details(start_time:, path:, body:)
          return unless ::Gitlab::SafeRequestStore.active?

          duration = (Time.current - start_time)

          ::Gitlab::Instrumentation::Zoekt.increment_request_count
          ::Gitlab::Instrumentation::Zoekt.add_duration(duration)

          ::Gitlab::Instrumentation::Zoekt.add_call_details(
            duration: duration,
            method: 'POST',
            path: path,
            body: body
          )
        end

        def zoekt_indexer_truncate_path
          use_new_zoekt_indexer? ? '/indexer/truncate' : '/truncate'
        end

        def use_new_zoekt_indexer?
          ::Feature.enabled?(:use_new_zoekt_indexer)
        end

        def username
          @username ||= File.exist?(username_file) ? File.read(username_file).chomp : nil
        end

        def password
          @password ||= File.exist?(password_file) ? File.read(password_file).chomp : nil
        end

        def username_file
          Gitlab.config.zoekt.username_file
        end

        def password_file
          Gitlab.config.zoekt.password_file
        end

        def logger
          @logger ||= ::Zoekt::Logger.build
        end
      end
    end
  end
end
