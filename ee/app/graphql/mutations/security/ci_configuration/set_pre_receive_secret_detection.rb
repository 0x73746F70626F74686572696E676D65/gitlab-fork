# frozen_string_literal: true

module Mutations
  module Security
    module CiConfiguration
      class SetPreReceiveSecretDetection < BaseMutation
        graphql_name 'SetPreReceiveSecretDetection'

        include FindsNamespace

        description <<~DESC
          Enable/disable secret push protection for the given project.
        DESC

        argument :namespace_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the namespace (project).'

        argument :enable, GraphQL::Types::Boolean,
          required: true,
          description: 'Desired status for secret push protection feature.'

        field :pre_receive_secret_detection_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether the feature is enabled.'

        authorize :enable_pre_receive_secret_detection

        def resolve(namespace_path:, enable:)
          namespace = find_namespace(namespace_path)

          response = ::Security::Configuration::SetPreReceiveSecretDetection
            .execute(current_user: current_user, namespace: namespace, enable: enable)

          { pre_receive_secret_detection_enabled: response.payload[:enabled], errors: response.errors }
        end

        private

        def find_namespace(namespace_path)
          namespace = authorized_find!(namespace_path)
          # This will be removed following the completion of https://gitlab.com/gitlab-org/gitlab/-/issues/451357
          unless namespace.is_a? Project
            raise_resource_not_available_error! 'Setting only available for project namespaces.'
          end

          namespace
        end
      end
    end
  end
end
