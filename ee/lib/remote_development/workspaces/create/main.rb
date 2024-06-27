# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
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
              .and_then(Authorizer.method(:authorize))
              .and_then(DevfileFetcher.method(:fetch))
              .and_then(PreFlattenDevfileValidator.method(:validate))
              .and_then(DevfileFlattener.method(:flatten))
              .and_then(PostFlattenDevfileValidator.method(:validate))
              .map(VolumeDefiner.method(:define))
              .map(ToolsComponentInjector.method(:inject))
              .map(ProjectClonerComponentInjector.method(:inject))
              .map(VolumeComponentInjector.method(:inject))
              .and_then(Creator.method(:create))

          # rubocop:disable Lint/DuplicateBranch -- Rubocop doesn't know the branches are different due to destructuring
          case result
          in { err: Unauthorized => message }
            generate_error_response_from_message(message: message, reason: :unauthorized)
          in { err: WorkspaceCreateParamsValidationFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreateDevfileYamlParseFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreateDevfileLoadFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreatePreFlattenDevfileValidationFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreateDevfileFlattenFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreatePostFlattenDevfileValidationFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { err: WorkspaceCreateFailed => message }
            generate_error_response_from_message(message: message, reason: :bad_request)
          in { ok: WorkspaceCreateSuccessful => message }
            { status: :success, payload: message.content }
          else
            raise UnmatchedResultError.new(result: result)
          end
          # rubocop:enable Lint/DuplicateBranch
        end
      end
    end
  end
end
