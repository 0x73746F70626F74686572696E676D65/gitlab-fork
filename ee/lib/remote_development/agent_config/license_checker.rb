# frozen_string_literal: true

module RemoteDevelopment
  module AgentConfig
    class LicenseChecker
      include Messages

      # @param [Hash] context
      # @return [Result]
      def self.check_license(context)
        if License.feature_available?(:remote_development)
          Result.ok(context)
        else
          Result.err(LicenseCheckFailed.new)
        end
      end
    end
  end
end
