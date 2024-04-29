# frozen_string_literal: true

module Elastic
  module Latest
    class WikiClassProxy < ApplicationClassProxy
      include Routing
      include GitClassProxy

      def es_type
        'wiki_blob'
      end

      def elastic_search_as_wiki_page(*args, **kwargs)
        elastic_search_as_found_blob(*args, **kwargs).map! { |blob| Gitlab::Search::FoundWikiPage.new(blob) }
      end

      def elastic_search(
        query, type: es_type, page: Gitlab::SearchResults::DEFAULT_PAGE,
        per: Gitlab::SearchResults::DEFAULT_PER_PAGE, options: {}
      )
        query_hash = search_query(query, options)
        query_hash[:size] = if options[:count_only]
                              0
                            else
                              query_hash[:from] = per * (page - 1)
                              query_hash[:sort] = [:_score]
                              per
                            end

        res = search(query_hash, options)
        { type.pluralize.to_sym => { results: res.results, total_count: res.size } }
      end

      def routing_options(options)
        return {} if routing_disabled?(options)

        ids = options[:root_ancestor_ids].presence || []
        routing = build_routing(ids, prefix: 'n')
        { routing: routing.presence }.compact
      end

      private

      def search_query(query, options)
        Wiki.use_separate_indices? ? query_for_separate_index(query, options) : query_for_main_index(query, options)
      end

      def query_for_separate_index(query, options)
        search_scope = options[:search_scope]
        return match_none if search_scope == 'group' && options[:group_ids].blank?

        bool_expr = { filter: [], must: [], must_not: [] }
        query_hash = { query: { bool: bool_expr } }
        bool_expr = apply_simple_query_string(
          name: context.name(:wiki_blob, :match, :search_terms, :separate_index),
          query: query,
          fields: %w[content file_name path],
          bool_expr: bool_expr,
          count_only: options[:count_only]
        )
        bool_expr[:must_not] << { term: { wiki_access_level: Featurable::DISABLED } }

        if search_scope == 'project' && options[:repository_id].present?
          query_hash = add_filter(query_hash, :query, :bool, :filter) do
            { term: { rid: options[:repository_id] } }
          end
        end

        query_hash = archived_filter(query_hash) if archived_filter_applicable_on_wiki?(options)
        user = options[:current_user]
        query_hash = add_namespace_ancestry_filter(query_hash, options[:group_id], user) if search_scope == 'group'

        if options.key?(:current_user)
          return query_hash if user&.can_read_all_resources?

          query_hash[:query][:bool][:should] = wiki_permission_filter(user, options)
          query_hash[:query][:bool][:minimum_should_match] = 1 unless query_hash[:query][:bool][:should].empty?
        end

        query_hash
      end

      def wiki_permission_filter(user, options)
        should_collection = []
        should_collection = add_should_query_for_public_documents(should_collection)
        should_collection = add_should_query_for_internal_documents(should_collection, user)
        should_collection = add_should_query_for_private_group_documents(should_collection, user, options)
        add_should_query_for_private_project_documents(should_collection, user, options)
      end

      def add_should_query_for_private_group_documents(should_collection, user, options)
        return should_collection if options[:search_scope] == 'project' || user.nil?

        finder_params = { min_access_level: ::Gitlab::Access::GUEST }
        if options[:search_scope] == 'group'
          searched_group = searched_group(options[:group_id], user)
          finder_params[:filter_group_ids] = searched_group.self_and_descendants.pluck_primary_key if searched_group
        end

        group_ids = GroupsFinder.new(options[:current_user], finder_params).execute.pluck("#{Group.table_name}.#{Group.primary_key}") # rubocop: disable CodeReuse/ActiveRecord -- We need to get only ids
        return should_collection if group_ids.empty?

        query_hash = add_private_visibility_filters
        query_hash[:bool][:_name] = :private_group_documents_filter
        query_hash[:bool][:must_not] = { exists: { field: 'project_id' } }
        should_collection << add_filter(query_hash, :bool, :filter) do
          { terms: { group_id: group_ids } }
        end
      end

      def add_should_query_for_private_project_documents(should_collection, user, options)
        return should_collection if options[:project_ids].blank? || user.nil?

        ids = options[:project_ids]
        # Don't trust on supplied project_ids. Filter out non accessible project_ids
        project_ids = Project.id_in(ids).visible_to_user_and_access_level(user, Gitlab::Access::GUEST).pluck_primary_key
        return should_collection if project_ids.empty?

        query_hash = add_private_visibility_filters
        query_hash[:bool][:_name] = :private_project_documents_filter
        should_collection << add_filter(query_hash, :bool, :filter) do
          { terms: { project_id: project_ids } }
        end
      end

      def add_should_query_for_public_documents(should_collection)
        query = add_filter({ bool: { filter: [] } }, :bool, :filter) do
          { term: { visibility_level: Gitlab::VisibilityLevel::PUBLIC } }
        end
        query[:bool][:_name] = :public_documents_filter
        should_collection << add_filter(query, :bool, :filter) do
          { term: { wiki_access_level: Featurable::ENABLED } }
        end
      end

      def add_should_query_for_internal_documents(should_collection, user)
        return should_collection if user.nil? || user&.external?

        query = add_filter({ bool: { filter: [] } }, :bool, :filter) do
          { term: { visibility_level: Gitlab::VisibilityLevel::INTERNAL } }
        end
        query[:bool][:_name] = :internal_documents_filter
        should_collection << add_filter(query, :bool, :filter) do
          { term: { wiki_access_level: Featurable::ENABLED } }
        end
      end

      def add_private_visibility_filters
        add_filter({ bool: { filter: [] } }, :bool, :filter) do
          { terms: { wiki_access_level: [Featurable::PRIVATE, Featurable::ENABLED] } }
        end
      end

      def add_namespace_ancestry_filter(query_hash, group_id, user)
        group = searched_group(group_id, user)
        return query_hash unless group

        add_filter(query_hash, :query, :bool, :filter) do
          context.name(:ancestry_filter) do
            {
              prefix: { traversal_ids: { _name: context.name(:descendants), value: group.elastic_namespace_ancestry } }
            }
          end
        end
      end

      # rubocop:disable Metrics/AbcSize -- This method is copied from GitClassProxy. Once the migration migrate_wikis_to_separate_index gets obsolete, we can completely remove this method
      # rubocop:disable Metrics/PerceivedComplexity -- Same as above
      # rubocop:disable Metrics/CyclomaticComplexity -- Same as above
      def query_for_main_index(query, options)
        options = options.merge(features: 'wiki', scope: es_type, no_join_project: true)
        bool_expr = ::Gitlab::Elastic::BoolExpr.new
        query_hash = { query: { bool: bool_expr } }
        fields = %w[blob.content blob.file_name blob.path]
        bool_expr = apply_simple_query_string(
          name: context.name(:wiki_blob, :match, :search_terms, :main_index),
          query: query,
          fields: fields,
          bool_expr: bool_expr,
          count_only: options[:count_only]
        )

        if options.key?(:current_user)
          query_hash = context.name(:blob, :authorized) do
            authorization_filter(query_hash, options.merge(traversal_ids_prefix: :traversal_ids))
          end
        end

        bool_expr[:filter] << {
          term: {
            type: {
              _name: context.name(:doc, :is_a, es_type),
              value: 'wiki_blob'
            }
          }
        }
        options[:project_id_field] = 'blob.rid'
        repository_ids = [options[:repository_id]].flatten
        filters = []
        if repository_ids.any?
          unless ::Elastic::DataMigrationService.migration_has_finished?(:add_suffix_project_in_wiki_rid)
            repository_ids = repository_ids.flat_map do |rid|
              /wiki_project_\d+/.match?(rid) ? [rid, rid.gsub(/wiki_project/, 'wiki')] : rid
            end.uniq
          end

          filters << {
            terms: {
              _name: context.name(es_type, :related, :repositories),
              (options[:project_id_field] || "#{es_type}.rid") => repository_ids
            }
          }
        end

        filters << options[:additional_filter] if options[:additional_filter]
        bool_expr[:filter] += filters if filters.any?
        options[:order] = :default if options[:order].blank?
        if options[:highlight] && !options[:count_only]
          # Highlighted text fragments do not work well for code as we want to show a few whole lines of code.
          # Set number_of_fragments to 0 to get the whole content to determine the exact line number that was
          # highlighted.
          query_hash[:highlight] = {
            pre_tags: [HIGHLIGHT_START_TAG],
            post_tags: [HIGHLIGHT_END_TAG],
            number_of_fragments: 0,
            fields: {
              "blob.content" => {},
              "blob.file_name" => {}
            }
          }
        end

        query_hash = archived_filter(query_hash) if archived_filter_applicable_on_wiki?(options)
        repository_ids = [options[:repository_id]].flatten
        options[:project_ids] = repository_ids.map { |id| id.to_s[/\d+/].to_i } if repository_ids.any?
        query_hash
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/CyclomaticComplexity

      def archived_filter_applicable_on_wiki?(options)
        !options[:include_archived] && options[:search_scope] != 'project' &&
          ::Elastic::DataMigrationService.migration_has_finished?(:reindex_wikis_to_fix_routing_and_backfill_archived)
      end

      def searched_group(group_id, user)
        group = Group.find_by_id(group_id)
        return unless group

        return if (group.internal? && (user.nil? || user.external?)) || (group.private? && !group.member?(user))

        group
      end
    end
  end
end
