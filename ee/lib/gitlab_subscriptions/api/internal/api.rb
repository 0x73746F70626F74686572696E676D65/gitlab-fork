# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class API < ::API::Base
        before do
          authenticated_as_admin!
        end

        mount ::GitlabSubscriptions::API::Internal::Subscriptions
      end
    end
  end
end
