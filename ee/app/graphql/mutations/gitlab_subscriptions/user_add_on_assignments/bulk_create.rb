# frozen_string_literal: true

module Mutations
  module GitlabSubscriptions
    module UserAddOnAssignments
      class BulkCreate < BaseMutation
        graphql_name 'UserAddOnAssignmentBulkCreate'
        MAX_USER_ASSIGNMENT_LIMIT = 50
        MAX_USER_ASSIGNMENT_ERROR = "The number of users to be assigned in a single API call " \
                                    "should be less than #{MAX_USER_ASSIGNMENT_LIMIT}."
                                      .freeze
        include ::GitlabSubscriptions::CodeSuggestionsHelper

        argument :add_on_purchase_id, ::Types::GlobalIDType[::GitlabSubscriptions::AddOnPurchase],
          required: true, description: 'Global ID of AddOnPurchase to be assigned to.'

        argument :user_ids,
          type: [::Types::GlobalIDType[::User]],
          required: true,
          description: 'Global IDs of user to be assigned.',
          prepare: ->(global_ids, _ctx) { global_ids&.filter_map { |gid| gid.model_id.to_i } }

        field :add_on_purchase, ::Types::GitlabSubscriptions::AddOnPurchaseType,
          null: true,
          description: 'AddOnPurchase state after mutation.'

        field :users,
          type: ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
          null: true,
          description: 'Users who the add-on purchase was assigned to.'

        authorize :admin_add_on_purchase

        def resolve(**args)
          result = ::GitlabSubscriptions::DuoPro::BulkAssignService.new(
            add_on_purchase: add_on_purchase,
            user_ids: args[:user_ids]
          ).execute

          if result.success?
            {
              add_on_purchase: add_on_purchase,
              users: result[:users],
              errors: []
            }
          else
            { errors: result.errors }
          end
        end

        def ready?(add_on_purchase_id:, user_ids:)
          @add_on_purchase = authorized_find!(id: add_on_purchase_id)

          if user_ids.size > MAX_USER_ASSIGNMENT_LIMIT
            raise Gitlab::Graphql::Errors::ArgumentError, MAX_USER_ASSIGNMENT_ERROR
          end

          raise_resource_not_available_error! unless feature_enabled? && add_on_purchase&.active? && user_ids.any?

          super
        end

        private

        attr_reader :add_on_purchase

        def feature_enabled?
          duo_pro_bulk_user_assignment_available?(add_on_purchase&.namespace)
        end
      end
    end
  end
end
