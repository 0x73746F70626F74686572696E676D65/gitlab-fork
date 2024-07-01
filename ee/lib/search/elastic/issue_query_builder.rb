# frozen_string_literal: true

module Search
  module Elastic
    class IssueQueryBuilder < QueryBuilder
      extend ::Gitlab::Utils::Override

      DOC_TYPE = 'issue'

      def build
        query_hash =
          if query =~ /#(\d+)\z/
            ::Search::Elastic::Queries.by_iid(iid: Regexp.last_match(1), doc_type: DOC_TYPE)
          else
            # iid field can be added here as lenient option will
            # pardon format errors, like integer out of range.
            fields = %w[iid^3 title^2 description]

            if !::Search::Elastic::Queries::ADVANCED_QUERY_SYNTAX_REGEX.match?(query) &&
                Feature.enabled?(:search_uses_match_queries, options[:current_user])
              ::Search::Elastic::Queries.by_multi_match_query(fields: fields, query: query, options: options)
            else
              ::Search::Elastic::Queries.by_simple_query_string(fields: fields, query: query, options: options)
            end
          end

        query_hash = ::Search::Elastic::Filters.by_authorization(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_confidentiality(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_state(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_not_hidden(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_label_ids(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Filters.by_archived(query_hash: query_hash, options: options)

        if hybrid_issue_search?
          query_hash = ::Search::Elastic::Queries.by_knn(query_hash: query_hash, query: query, options: options)
        end

        return ::Search::Elastic::Aggregations.by_label_ids(query_hash: query_hash) if options[:aggregation]

        query_hash = ::Search::Elastic::Formats.source_fields(query_hash: query_hash, options: options)
        query_hash = ::Search::Elastic::Formats.size(query_hash: query_hash, options: options)

        ::Search::Elastic::Sorts.sort_by(query_hash: query_hash, options: options)
      end

      private

      override :extra_options
      def extra_options
        {
          doc_type: DOC_TYPE,
          features: 'issues',
          traversal_ids_prefix: :namespace_ancestry_ids,
          authorization_use_traversal_ids: true
        }
      end

      # rubocop: disable Gitlab/FeatureFlagWithoutActor -- global flags
      def hybrid_issue_search?
        return false unless options[:hybrid_similarity]
        return false unless Feature.enabled?(:search_issues_hybrid_search)
        return false unless Feature.enabled?(:ai_global_switch, type: :ops)
        return false unless Gitlab::Saas.feature_available?(:ai_vertex_embeddings)
        return false unless ::Elastic::DataMigrationService.migration_has_finished?(:add_embedding_to_issues)

        project = Project.id_in(options[:project_ids])&.first
        user = options[:current_user]

        return false unless project && user

        Feature.enabled?(:elasticsearch_issue_embedding, project, type: :ops) &&
          user.any_group_with_ai_available?
      end
      # rubocop: enable Gitlab/FeatureFlagWithoutActor
    end
  end
end
