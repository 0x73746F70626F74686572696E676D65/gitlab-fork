# frozen_string_literal: true

module API
  module Helpers
    module CloudConnector
      include ::API::Helpers::GlobalIds

      def cloud_connector_headers(user)
        instance_id, user_id = global_instance_and_user_id_for(user)

        {
          'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
          'X-Gitlab-Instance-Id' => instance_id,
          'X-Gitlab-Realm' => Gitlab::CloudConnector.gitlab_realm,
          'X-Gitlab-Version' => Gitlab.version_info.to_s
        }.tap do |result|
          result['X-Gitlab-Global-User-Id'] = user_id if user
        end
      end
    end
  end
end
