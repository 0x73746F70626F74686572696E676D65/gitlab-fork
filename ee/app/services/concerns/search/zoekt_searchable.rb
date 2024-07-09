# frozen_string_literal: true

module Search
  module ZoektSearchable
    def use_zoekt?
      # TODO: rename to search_code_with_zoekt?
      # https://gitlab.com/gitlab-org/gitlab/-/issues/421619
      return false if params[:basic_search] || skip_api?
      return false unless ::Search::Zoekt.enabled_for_user?(current_user) && zoekt_searchable_scope?
      return false if Feature.enabled?(:disable_zoekt_search_for_saas, root_ancestor)

      zoekt_node_available_for_search?
    end

    def zoekt_searchable_scope
      raise NotImplementedError
    end

    def zoekt_searchable_scope?
      scope == 'blobs' && zoekt_searchable_scope.try(:search_code_with_zoekt?)
    end

    def root_ancestor
      zoekt_searchable_scope&.root_ancestor
    end

    def zoekt_projects
      @zoekt_projects ||= projects
    end

    def zoekt_filters
      { language: params[:language], include_archived: params[:include_archived] }
    end

    def zoekt_node_id
      @zoekt_node_id ||= zoekt_nodes.first.id
    end

    def zoekt_nodes
      # Note: there will be more zoekt nodes whenever replicas are introduced.
      @zoekt_nodes ||= zoekt_searchable_scope.root_ancestor.zoekt_enabled_namespace.nodes
    end

    def zoekt_node_available_for_search?
      ::Search::Zoekt::CircuitBreaker.new(*zoekt_nodes).operational?
    end

    def skip_api?
      params[:source] == 'api' &&
        Feature.disabled?(:zoekt_search_api, root_ancestor, type: :ops)
    end

    def zoekt_search_results
      ::Search::Zoekt::SearchResults.new(
        current_user,
        params[:search],
        zoekt_projects,
        node_id: zoekt_node_id,
        order_by: params[:order_by],
        sort: params[:sort],
        multi_match_enabled: params[:multi_match_enabled],
        chunk_count: params[:chunk_count],
        filters: zoekt_filters,
        modes: { regex: params[:regex] }
      )
    end
  end
end
