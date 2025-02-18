# frozen_string_literal: true

module EE
  module Search
    module GlobalService
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize
      include ::Search::Elasticsearchable
      include ::Search::ZoektSearchable

      override :execute
      def execute
        return zoekt_search_results if use_zoekt?
        return super unless use_elasticsearch?

        ::Gitlab::Elastic::SearchResults.new(
          current_user,
          params[:search],
          elastic_projects,
          public_and_internal_projects: elastic_global,
          order_by: params[:order_by],
          sort: params[:sort],
          filters: filters
        )
      end

      override :zoekt_searchable_scope?
      def zoekt_searchable_scope?
        scope == 'blobs' && ::Feature.enabled?(:zoekt_cross_namespace_search, current_user)
      end

      override :root_ancestor
      def root_ancestor
        nil
      end

      override :zoekt_node_id
      def zoekt_node_id
        nil
      end

      # This method isn't compatible with multi-node search, so we override it
      # to always return true.
      override :zoekt_node_available_for_search?
      def zoekt_node_available_for_search?
        true
      end

      def elasticsearchable_scope
        nil
      end

      def elastic_global
        true
      end

      def elastic_projects
        # For elasticsearch we need the list of projects to be as small as
        # possible since they are loaded from the DB and sent in the
        # Elasticsearch query. It should only be strictly the project IDs the
        # user has been given authorization for. The Elasticsearch query will
        # additionally take care of public projects. This behaves differently
        # to the searching Postgres case in which this list of projects is
        # intended to be all projects that should appear in the results.
        strong_memoize(:elastic_projects) do
          if current_user&.can_read_all_resources?
            :any
          elsif current_user
            current_user.authorized_projects.pluck(:id) # rubocop: disable CodeReuse/ActiveRecord
          else
            []
          end
        end
      end

      override :allowed_scopes
      def allowed_scopes
        return super unless use_elasticsearch?

        strong_memoize(:ee_allowed_scopes) do
          super + %w[blobs commits epics notes wiki_blobs]
        end
      end
    end
  end
end
