# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Client # rubocop:disable Search/NamespacedClass
        include ::Gitlab::Loggable
        INDEXING_TIMEOUT_S = 30.minutes.to_i
        MAXIMUM_THREADS = 16
        CONTEXT_LINES_COUNT = 1

        TooManyRequestsError = Class.new(StandardError)

        class << self
          def instance
            @instance ||= new
          end

          delegate :search, :search_multi_node, :index, :delete, :truncate, to: :instance
        end

        def search(query, num:, project_ids:, node_id:, search_mode:)
          start = Time.current

          q = format_query(query, search_mode: search_mode)

          payload = {
            Q: q,
            Opts: {
              TotalMaxMatchCount: num,
              NumContextLines: CONTEXT_LINES_COUNT
            }
          }

          # Safety net because Zoekt will match all projects if you provide
          # an empty array.
          raise 'Not possible to search without at least one project specified' if project_ids.blank?
          raise 'Global search is not supported' if project_ids == :any

          payload[:RepoIDs] = project_ids
          path = '/api/search'
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          with_node_exception_handling(target_node) do
            response = post_request(join_url(target_node.search_base_url, path), payload)

            log_error('Zoekt search failed', status: response.code, response: response.body) unless response.success?

            Gitlab::Search::Zoekt::Response.new parse_response(response)
          end
        ensure
          add_request_details(start_time: start, path: path, body: payload)
        end

        def search_multi_node(query, num:, targets:, search_mode:)
          if targets.size > MAXIMUM_THREADS
            raise ArgumentError, "Too many targets #{targets.size}, maximum allowed #{MAXIMUM_THREADS}"
          end

          threads = []

          targets.each do |node_id, project_ids|
            threads << Thread.new do
              response = search(query, num: num, project_ids: project_ids, node_id: node_id, search_mode: search_mode)

              [node_id, response]
            end
          end

          Gitlab::Search::Zoekt::MultiNodeResponse.new threads.each(&:join).map(&:value).to_h
        end

        def index(project, node_id, force: false, callback_payload: {})
          raise 'Node can not be found' unless node(node_id)

          callback_payload[:project_id] = project.id
          payload = indexing_payload(project, force: force, callback_payload: callback_payload)

          response = zoekt_indexer_post('/indexer/index', payload, node_id)

          raise TooManyRequestsError if response.code == 429
          raise "Request failed with: #{response.inspect}" unless response.success?

          parsed_response = parse_response(response)
          raise parsed_response['Error'] if parsed_response['Error']

          response
        end

        def delete(node_id:, project_id:)
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          response = delete_request(join_url(target_node.index_base_url, "/indexer/index/#{project_id}"))

          raise "Request failed with: #{response.inspect}" unless response.success?

          parsed_response = parse_response(response)
          raise parsed_response['Error'] if parsed_response['Error']

          response
        end

        def truncate
          ::Search::Zoekt::Node.find_each do |node|
            post_request(join_url(node.index_base_url, '/indexer/truncate'))
          end
        end

        private

        def post_request(url, payload = {}, **options)
          defaults = {
            headers: { 'Content-Type' => 'application/json' },
            body: payload.to_json,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.post(
            url,
            defaults.merge(options)
          )
        rescue *Gitlab::HTTP::HTTP_ERRORS => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
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
        rescue *Gitlab::HTTP::HTTP_ERRORS => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def zoekt_indexer_post(path, payload, node_id)
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          post_request(
            join_url(target_node.index_base_url, path),
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

        def indexing_payload(project, force:, callback_payload:)
          repository_storage = project.repository_storage
          connection_info = Gitlab::GitalyClient.connection_data(repository_storage)
          repository_path = "#{project.repository.disk_path}.git"
          address = connection_info['address']

          # This code is needed to support relative unix: connection strings. For example, specs
          if address.match?(%r{\Aunix:[^/.]})
            path = address.split('unix:').last
            address = "unix:#{Rails.root.join(path)}"
          end

          payload = {
            GitalyConnectionInfo: {
              Address: address,
              Token: connection_info['token'],
              Storage: repository_storage,
              Path: repository_path
            },
            Callback: { name: 'index', payload: callback_payload },
            RepoId: project.id,
            FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
            Timeout: "#{INDEXING_TIMEOUT_S}s"
          }

          payload[:Force] = force if force

          payload
        end

        def node(node_id)
          ::Search::Zoekt::Node.find_by_id(node_id)
        end

        def with_node_exception_handling(zoekt_node)
          return yield if Feature.disabled?(:zoekt_node_backoffs, type: :ops)

          backoff = zoekt_node.backoff

          if backoff.enabled?
            log_error('Zoekt node in backoff', node_id: zoekt_node.id, expire_at: backoff.expires_at)
            raise ::Search::Zoekt::Errors::BackoffError,
              'Zoekt node cannot be used yet because it is in back off period'
          end

          begin
            yield
          rescue StandardError => err
            backoff.backoff!
            raise(err)
          end
        end

        def join_url(base_url, path)
          # We can't use URI.join because it doesn't work properly with something like
          # URI.join('http://example.com/api', 'index') => #<URI::HTTP http://example.com/index>
          url = [base_url, path].join('/')
          url.gsub(%r{(?<!:)/+}, '/') # Remove duplicate slashes
        end

        def parse_response(response)
          ::Gitlab::Json.parse(response.body).with_indifferent_access
        rescue Gitlab::Json.parser_error => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
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
          @logger ||= ::Search::Zoekt::Logger.build
        end

        def log_error(message, payload = {})
          logger.error(build_structured_payload(**payload.merge(message: message)))
        end

        def format_query(query, search_mode:)
          case search_mode.to_sym
          when :exact
            ::Search::Zoekt::Query.new(query).exact_search_query
          when :regex
            query
          else
            raise ArgumentError, 'Not a valid search_mode'
          end
        end
      end
    end
  end
end
