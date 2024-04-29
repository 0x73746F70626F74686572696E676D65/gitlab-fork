# frozen_string_literal: true

module Mutations
  module MemberRoles
    class Create < Base
      graphql_name 'MemberRoleCreate'

      include ::GitlabSubscriptions::SubscriptionHelper
      include Mutations::ResolvesNamespace

      argument :base_access_level,
        ::Types::MemberAccessLevelEnum,
        required: true,
        description: 'Base access level for the custom role.'

      argument :group_path, GraphQL::Types::ID,
        required: false,
        description: 'Group the member role to mutate is in. Required for SaaS.'

      def ready?(**args)
        raise Gitlab::Graphql::Errors::ArgumentError, 'group_path argument is required.' if missing_group_path?(args)

        if extra_group_path?(args)
          raise Gitlab::Graphql::Errors::ArgumentError, 'group_path argument is not allowed on self-managed instances.'
        end

        super
      end

      def resolve(**args)
        group = find_group(args.delete(:group_path))

        params = canonicalize(args.merge(namespace: group))
        response = ::MemberRoles::CreateService.new(current_user, params).execute

        raise_resource_not_available_error! if response.error? && response.reason == :unauthorized

        {
          member_role: response.payload[:member_role],
          errors: response.errors
        }
      end

      private

      def find_group(group_path)
        return unless group_path

        group = ::Gitlab::Graphql::Lazy.force(find_object(group_path: group_path))

        raise_resource_not_available_error! unless group

        group
      end

      def find_object(group_path:)
        resolve_namespace(full_path: group_path)
      end

      def missing_group_path?(args)
        return false unless gitlab_com_subscription?

        args[:group_path].blank?
      end

      def extra_group_path?(args)
        return false if gitlab_com_subscription?

        args[:group_path].present?
      end

      def canonicalize(args)
        permissions = args.delete(:permissions) || []
        permissions.each_with_object(args) do |permission, new_args|
          new_args[permission.downcase] = true
        end
      end
    end
  end
end
