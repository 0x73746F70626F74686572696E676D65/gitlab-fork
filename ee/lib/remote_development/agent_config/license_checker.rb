# frozen_string_literal: true

module RemoteDevelopment
  module AgentConfig
    class LicenseChecker
      include Messages

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.check_license(context)
        if License.feature_available?(:remote_development)
          Gitlab::Fp::Result.ok(context)
        else
          Gitlab::Fp::Result.err(LicenseCheckFailed.new)
        end
      end
    end
  end
end
