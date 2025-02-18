# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappings
    module Create
      class Main
        include Messages
        extend MessageSupport

        # @param [Hash] context
        # @return [Hash]
        # @raise [UnmatchedResultError]
        def self.main(context)
          initial_result = Gitlab::Fp::Result.ok(context)

          result =
            initial_result
              .and_then(ClusterAgentValidator.method(:validate))
              .and_then(MappingCreator.method(:create))
          case result
          in { err: NamespaceClusterAgentMappingAlreadyExists |
            NamespaceClusterAgentMappingCreateFailed |
            NamespaceClusterAgentMappingCreateValidationFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { ok: NamespaceClusterAgentMappingCreateSuccessful => message }
            { status: :success, payload: message.content }
          else
            raise UnmatchedResultError.new(result: result)
          end
        end
      end
    end
  end
end
