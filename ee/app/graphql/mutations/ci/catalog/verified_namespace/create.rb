# frozen_string_literal: true

module Mutations
  module Ci
    module Catalog
      module VerifiedNamespace
        class Create < Mutations::BaseMutation
          graphql_name 'VerifiedNamespaceCreate'

          description 'Create a verified namespace and mark all child catalog resources ' \
            'with the passed verification level info.'

          include ::GitlabSubscriptions::SubscriptionHelper

          authorize :admin_all_resources

          include Mutations::ResolvesNamespace

          argument :namespace_path,
            GraphQL::Types::ID,
            required: true,
            description: 'Root namespace path.'

          argument :verification_level,
            Types::Ci::Catalog::Resources::VerificationLevelEnum,
            required: true,
            description: 'Verification level used to indicate the verification for namespace given by Gitlab.'

          def resolve(namespace_path:, verification_level:)
            unless gitlab_com_subscription?
              return { errors: ["Can't perform this action on a non-Gitlab.com instance."] }
            end

            namespace = authorized_find!(namespace_path: namespace_path)
            result = ::Ci::Catalog::VerifyNamespaceService.new(namespace, verification_level).execute

            errors = result.success? ? [] : [result.message]
            {
              errors: errors
            }
          end

          private

          def find_object(namespace_path:)
            resolve_namespace(full_path: namespace_path)
          end
        end
      end
    end
  end
end
