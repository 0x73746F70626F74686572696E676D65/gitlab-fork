# frozen_string_literal: true

module Resolvers
  module MemberRoles
    class RolesResolver < BaseResolver
      include LooksAhead

      type Types::MemberRoles::MemberRoleType, null: true

      argument :id, ::Types::GlobalIDType[::MemberRole],
        required: false,
        description: 'Global ID of the member role to look up.'

      argument :order_by, ::Types::MemberRoles::OrderByEnum,
        required: false,
        description: 'Ordering column. Default is NAME.'

      argument :sort, ::Types::SortDirectionEnum,
        required: false,
        description: 'Ordering column. Default is ASC.'

      def resolve_with_lookahead(id: nil, order_by: nil, sort: nil)
        params = {}
        params = { parent: object } if object
        params[:id] = id.model_id if id.present?
        params[:order_by] = order_by.presence || :name
        params[:sort] = sort.present? ? sort.to_sym : :asc

        member_roles = ::MemberRoles::RolesFinder.new(current_user, params).execute
        member_roles = member_roles.with_members_count if selects_field?(:members_count)

        offset_pagination(member_roles)
      end

      private

      def selected_fields
        node_selection.selections.map(&:name)
      end

      def selects_field?(name)
        lookahead.selects?(:members_count) || selected_fields.include?(name)
      end
    end
  end
end
