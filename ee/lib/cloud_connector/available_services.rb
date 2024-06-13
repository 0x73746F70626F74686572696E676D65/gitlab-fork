# frozen_string_literal: true

module CloudConnector
  class AvailableServices
    extend Gitlab::Utils::StrongMemoize

    class << self
      def find_by_name(name)
        service_data_map = available_services

        return CloudConnector::MissingServiceData.new if service_data_map.empty?

        service_data_map[name]
      end

      def available_services
        strong_memoize(:available_services) do # rubocop:disable Gitlab/StrongMemoizeAttr -- class method
          access_data_reader.read_available_services
        end
      end

      def access_data_reader
        strong_memoize(:access_data_reader) do # rubocop:disable Gitlab/StrongMemoizeAttr -- class method
          if use_self_signed_token?
            SelfSigned::AccessDataReader.new
          else
            SelfManaged::AccessDataReader.new
          end
        end
      end

      private

      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- we don't have dedicated SM/.com Cloud Connector features
      # or other checks that would allow us to identify where the code is running. We rely on instance checks for now.
      # Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
      def use_self_signed_token?
        return true if Gitlab.org_or_com?

        # Identifies whether AI Gateway is self-hosted by the customer
        # Currently, it's controlled by a feature flag, env var and a deadline until the proper solution is implemented
        #
        # The set of AI features is controlled by:
        #
        # - For SM that are using Cloud Connector: by CDot
        # - For GitLab.com and SM with self-hosted AI Gateway: by ee/config/cloud_connector/access_data.yml file
        #
        # Unlike for GitLab.com, we cannot control the availability of the features for offline SM customers if
        # they do not upgrade regularly. This is why we introduce a cut-off date to make the features unavailable if the
        # customers do not upgrade.
        return false if ::Feature.disabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
        return false if Date.today >= Ai::SelfHostedModel::CUTOFF_DATE

        Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
      end
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
    end
  end
end
