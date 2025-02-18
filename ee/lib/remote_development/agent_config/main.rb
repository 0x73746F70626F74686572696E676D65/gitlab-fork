# frozen_string_literal: true

require 'active_model/errors'

module RemoteDevelopment
  module AgentConfig
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
            # NOTE: We rely on the authentication from the internal kubernetes endpoint and kas so we don't do any
            #       additional authorization checks here.
            #       See https://gitlab.com/gitlab-org/gitlab/-/issues/409038
            .and_then(LicenseChecker.method(:check_license))
            .and_then(Updater.method(:update))

        case result
        in { err: LicenseCheckFailed => message }
          generate_error_response_from_message(message: message, reason: :forbidden)
        in { err: AgentConfigUpdateFailed => message }
          generate_error_response_from_message(message: message, reason: :bad_request)
        in { ok: AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound => message }
          message.content => { skipped_reason: Symbol } # Type-check the payload before returning it
          { status: :success, payload: message.content }
        in { ok: AgentConfigUpdateSuccessful => message }
          { status: :success, payload: message.content }
        else
          raise UnmatchedResultError.new(result: result)
        end
      end
    end
  end
end
