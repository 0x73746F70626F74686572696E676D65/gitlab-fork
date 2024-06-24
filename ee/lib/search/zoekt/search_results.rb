# frozen_string_literal: true

module Search
  module Zoekt
    class SearchResults
      include ActionView::Helpers::NumberHelper
      include Gitlab::Utils::StrongMemoize

      ZOEKT_COUNT_LIMIT = 5_000
      DEFAULT_PER_PAGE = Gitlab::SearchResults::DEFAULT_PER_PAGE
      ZOEKT_TARGETS_CACHE_EXPIRES_IN = 10.minutes

      attr_reader :current_user, :query, :public_and_internal_projects, :order_by, :sort, :filters, :error, :modes

      # Limit search results by passed projects
      # It allows us to search only for projects user has access to
      attr_reader :projects, :node_id

      def initialize(current_user, query, projects, node_id: nil, order_by: nil, sort: nil, filters: {}, modes: {})
        @current_user = current_user
        @query = query
        @filters = filters
        @projects = filtered_projects(projects)
        @node_id = node_id
        @order_by = order_by
        @sort = sort
        @modes = modes
      end

      def limit_project_ids
        @limit_project_ids ||= projects.pluck_primary_key
      end

      def objects(_scope, page: 1, per_page: DEFAULT_PER_PAGE, preload_method: nil)
        blobs(page: page, per_page: per_page, preload_method: preload_method)
      end

      def formatted_count(_scope)
        limited_counter_with_delimiter(blobs_count)
      end

      def blobs_count
        @blobs_count ||= blobs.total_count
      end

      # These aliases act as an adapter to the Gitlab::SearchResults
      # interface, which is mostly implemented by this class.
      alias_method :limited_blobs_count, :blobs_count

      def parse_zoekt_search_result(result, project)
        ref = project.default_branch_or_main
        path = result[:path]
        basename = File.join(File.dirname(path), File.basename(path, '.*'))
        content = result[:content]
        project_id = project.id

        ::Gitlab::Search::FoundBlob.new(
          path: path,
          basename: basename,
          ref: ref,
          startline: [result[:line] - 1, 0].max,
          highlight_line: result[:line],
          data: content,
          project: project,
          project_id: project_id
        )
      end

      def aggregations(_scope)
        []
      end

      def highlight_map(_)
        nil
      end

      def failed?(_scope)
        error.present?
      end

      private

      def base_options
        {
          current_user: current_user,
          public_and_internal_projects: public_and_internal_projects,
          order_by: order_by,
          sort: sort,
          projects: projects,
          node_id: node_id
        }
      end

      def memoize_key(scope, page:, per_page:, count_only:)
        count_only ? "#{scope}_results_count".to_sym : "#{scope}_#{page}_#{per_page}"
      end

      def blobs(page: 1, per_page: DEFAULT_PER_PAGE, count_only: false, preload_method: nil)
        return Kaminari.paginate_array([]) if query.blank? || limit_project_ids.empty?

        strong_memoize(memoize_key(:blobs, page: page, per_page: per_page, count_only: count_only)) do
          search_as_found_blob(
            query,
            Repository,
            page: (page || 1).to_i,
            per_page: per_page,
            preload_method: preload_method
          )
        end
      end

      def limited_counter_with_delimiter(count)
        if count.nil?
          number_with_delimiter(0)
        elsif count >= ZOEKT_COUNT_LIMIT
          "#{number_with_delimiter(ZOEKT_COUNT_LIMIT)}+"
        else
          number_with_delimiter(count)
        end
      end

      def search_as_found_blob(query, _repositories, page:, per_page:, preload_method:)
        zoekt_search_and_wrap(query, page: page,
          per_page: per_page,
          preload_method: preload_method) do |result, project|
          parse_zoekt_search_result(result, project)
        end
      end

      # Performs zoekt search and parses the response
      #
      # @param query [String] search query
      # @param per_page [Integer] how many documents per page
      # @param options [Hash] additional options
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Array<Hash, Integer>] the results and total count
      def zoekt_search(query, per_page:, page_limit:)
        response = if node_id
                     ::Gitlab::Search::Zoekt::Client.search(
                       query,
                       num: ZOEKT_COUNT_LIMIT,
                       node_id: node_id,
                       project_ids: limit_project_ids,
                       search_mode: search_mode
                     )
                   else
                     ::Gitlab::Search::Zoekt::Client.search_multi_node(
                       query,
                       num: ZOEKT_COUNT_LIMIT,
                       targets: zoekt_targets,
                       search_mode: search_mode
                     )
                   end

        if response.failure?
          @blobs_count = 0
          @error = response.error_message
          return [{}, @blobs_count]
        end

        total_count = response.match_count.clamp(0, ZOEKT_COUNT_LIMIT)
        results = zoekt_extract_result_pages(response, per_page: per_page, page_limit: page_limit)

        [results, total_count]
      rescue ::Search::Zoekt::Errors::ClientConnectionError, ::Search::Zoekt::Errors::BackoffError => e
        @blobs_count = 0
        @error = e.message
        [{}, @blobs_count]
      end

      # Extracts results from the Zoekt response
      #
      # @param response [Hash] JSON response converted to hash
      # @param per_page [Integer] how many documents per page
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Hash<Integer, Array<Hash>>] results hash with pages as keys (zero-based)
      def zoekt_extract_result_pages(response, per_page:, page_limit:)
        results = {}
        i = 0

        response.each_file do |file|
          project_id = file[:Repository].to_i

          cont = file[:LineMatches].each do |match|
            current_page = i / per_page
            break false if current_page == page_limit

            results[current_page] ||= []
            results[current_page] << {
              project_id: project_id,
              content: [match[:Before], match[:Line], match[:After]].compact.map do |l|
                         Base64.decode64(l)
                       end.join("\n"),
              line: match[:LineNumber],
              path: file[:FileName]
            }

            i += 1
          end

          break unless cont
        end

        results
      end

      def zoekt_search_and_wrap(query, per_page:, page: 1, preload_method: nil, &blk)
        zoekt_cache = ::Search::Zoekt::Cache.new(
          query,
          current_user: current_user,
          page: page,
          per_page: per_page,
          project_ids: limit_project_ids,
          max_per_page: DEFAULT_PER_PAGE * 2,
          search_mode: search_mode
        )

        search_results, total_count = zoekt_cache.fetch do |page_limit|
          zoekt_search(query, per_page: per_page, page_limit: page_limit)
        end

        items, total_count = yield_each_zoekt_search_result(
          search_results[page - 1],
          preload_method,
          total_count,
          &blk
        )

        offset = (page - 1) * per_page
        Kaminari.paginate_array(items, total_count: total_count, limit: per_page, offset: offset)
      end

      def yield_each_zoekt_search_result(response, preload_method, total_count)
        return [[], total_count] if total_count == 0 || response.blank?

        project_ids = response.pluck(:project_id).uniq # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
        projects = Project.with_route.id_in(project_ids)
        projects = projects.public_send(preload_method) if preload_method # rubocop:disable GitlabSecurity/PublicSend -- Method calls are forwarded
        projects = projects.index_by(&:id)

        items = response.map do |result|
          project_id = result[:project_id]
          project = projects[project_id]

          if project.nil? || project.pending_delete?
            total_count -= 1
            next
          end

          yield(result, project)
        end

        # Remove results for deleted projects
        items.compact!

        [items, total_count]
      end

      def search_mode
        Gitlab::Utils.to_boolean(modes[:regex]) ? :regex : default_search_mode
      end

      def default_search_mode
        Feature.enabled?(:zoekt_exact_search, current_user) ? :exact : :regex
      end

      def filtered_projects(projects)
        return Project.all if projects == :any

        filtered_projects = projects.without_order
        filtered_projects = filtered_projects.non_archived unless filters[:include_archived]

        if Feature.enabled?(:search_add_fork_filter_to_zoekt, current_user) && !filters[:include_forked]
          filtered_projects = filtered_projects.not_a_fork
        end

        filtered_projects
      end

      def zoekt_targets
        sha = OpenSSL::Digest.hexdigest('SHA256', limit_project_ids.sort.join(','))
        cache_key = [self.class.name, :zoekt_targets, current_user&.id, sha]

        Rails.cache.fetch(cache_key, expires_in: ZOEKT_TARGETS_CACHE_EXPIRES_IN) do
          ::Search::Zoekt::RoutingService.execute(projects)
        end
      end
    end
  end
end
