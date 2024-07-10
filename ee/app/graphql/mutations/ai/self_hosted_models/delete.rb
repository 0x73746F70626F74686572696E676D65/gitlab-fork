# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      class Delete < Base
        graphql_name 'AiSelfHostedModelDelete'
        description "Deletes a self-hosted model."

        argument :id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: true,
          description: 'Global ID of the self-hosted model to delete.'

        def resolve(**args)
          check_feature_access!

          result = delete_self_hosted_model(args)

          if result[:errors].present?
            {
              self_hosted_model: nil,
              errors: Array(result[:errors])
            }
          else
            { self_hosted_model: result, errors: [] }
          end
        end

        private

        def delete_self_hosted_model(args)
          model = find_object(id: args[:id])

          return { errors: ["Self-hosted model not found"] } unless model

          model.destroy
        end

        def find_object(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Ai::SelfHostedModel).sync
        end
      end
    end
  end
end
