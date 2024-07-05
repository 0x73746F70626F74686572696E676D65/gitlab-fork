# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    class AddOnPurchaseResolver < BaseResolver
      type Types::GitlabSubscriptions::AddOnPurchaseType, null: true

      argument :add_on_type,
        type: ::Types::GitlabSubscriptions::AddOnTypeEnum,
        required: true,
        description: 'Type of add-on for the add-on purchase.'
      argument :namespace_id,
        type: ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'ID of namespace that the add-on was purchased for.'

      def resolve(add_on_type:, namespace_id: nil)
        ::GitlabSubscriptions::AddOnPurchase
          .active
          .by_add_on_name(add_on_type)
          .by_namespace(namespace_id&.model_id)
          .first
      end
    end
  end
end
