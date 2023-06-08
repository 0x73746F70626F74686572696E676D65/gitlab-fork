# frozen_string_literal: true

module Resolvers
  module Ci
    module Catalog
      class ResourceResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorize :read_namespace_catalog

        type ::Types::Ci::Catalog::ResourceType, null: true

        argument :id, ::Types::GlobalIDType[::Ci::Catalog::Resource],
          required: true,
          description: 'CI/CD Catalog resource global ID.'

        def resolve(id:)
          catalog_resource = ::Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(id))

          # this permission will be changed after resolving https://gitlab.com/gitlab-org/gitlab/-/issues/412948
          authorize!(catalog_resource&.project)

          catalog_resource
        end
      end
    end
  end
end
