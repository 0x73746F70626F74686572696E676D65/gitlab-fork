# frozen_string_literal: true

module Resolvers
  module Search
    module Blob
      class BlobSearchResolver < BaseResolver
        calls_gitaly!
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type Types::Search::Blob::BlobSearchType, null: true
        argument :chunk_count, type: GraphQL::Types::Int, required: false, alpha: { milestone: '17.2' },
          default_value: ::Search::Zoekt::MultiMatch::DEFAULT_REQUESTED_CHUNK_SIZE,
          description: 'Maximum chunks per file.'
        argument :group_id, ::Types::GlobalIDType[::Group], required: false, alpha: { milestone: '17.2' },
          description: 'Group to search in.'
        argument :page, type: GraphQL::Types::Int, required: false, default_value: 1, alpha: { milestone: '17.2' },
          description: 'Page number to fetch the results.'
        argument :per_page, type: GraphQL::Types::Int, required: false, alpha: { milestone: '17.2' },
          default_value: ::Search::Zoekt::SearchResults::DEFAULT_PER_PAGE, description: 'Number of results per page.'
        argument :project_id, ::Types::GlobalIDType[::Project], required: false, alpha: { milestone: '17.2' },
          description: 'Project to search in.'
        argument :repository_ref, type: GraphQL::Types::String, required: false, alpha: { milestone: '17.2' },
          description: 'Repository reference to search in.'
        argument :search, GraphQL::Types::String, required: true, description: 'Searched term.'

        def ready?(**args)
          @project = Project.find_by_id(args[:project_id]&.model_id)
          verify_repository_ref!(args[:repository_ref])
          @search_service = SearchService.new(current_user, {
            group_id: args[:group_id]&.model_id, project_id: args[:project_id]&.model_id, search: args[:search],
            page: args[:page], per_page: args[:per_page], multi_match_enabled: true, chunk_count: args[:chunk_count],
            scope: 'blobs'
          })
          @search_level = @search_service.level
          verify_global_search_is_allowed!
          @search_type = @search_service.search_type
          verify_search_is_zoekt!
          super
        end

        def resolve(**args)
          results(**args)
        end

        private

        def verify_repository_ref!(ref)
          return if @project.nil? || ref.blank? || (@project.default_branch == ref)

          raise Gitlab::Graphql::Errors::ArgumentError, 'Search is only allowed in project default branch'
        end

        def verify_global_search_is_allowed!
          return unless @search_level == 'global'
          return if @search_service.global_search_enabled_for_scope?

          raise Gitlab::Graphql::Errors::ArgumentError, 'Global search is not enabled for this scope'
        end

        def verify_search_is_zoekt!
          return if @search_type == 'zoekt'

          raise Gitlab::Graphql::Errors::ArgumentError, 'Zoekt search is not available for this request'
        end

        def results(**args)
          @results = @search_service.search_objects
          search_results = @search_service.search_results
          raise Gitlab::Graphql::Errors::BaseError, search_results.error if search_results.failed?

          {
            match_count: search_results.blobs_count, file_count: search_results.file_count,
            search_level: @search_level, search_type: @search_type,
            per_page: args[:per_page], files: @results
          }
        end
      end
    end
  end
end
