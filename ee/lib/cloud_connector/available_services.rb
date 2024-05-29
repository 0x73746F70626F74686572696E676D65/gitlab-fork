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
        # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- we don't have dedicated SM/.com Cloud Connector features
        # or other checks that would allow us to identify where the code is running. We rely on instance checks for now.
        # Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
        strong_memoize(:access_data_reader) do # rubocop:disable Gitlab/StrongMemoizeAttr -- class method
          Gitlab.org_or_com? ? GitlabCom::AccessDataReader.new : SelfManaged::AccessDataReader.new
        end
        # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
      end
    end
  end
end
