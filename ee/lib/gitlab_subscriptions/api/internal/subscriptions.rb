# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class Subscriptions < ::API::Base
        feature_category :plan_provisioning
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource :namespaces, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
              before do
                @namespace = find_namespace(params[:id])

                not_found!('Namespace') unless @namespace.present?
              end

              desc 'Returns the subscription for the namespace' do
                success ::API::Entities::GitlabSubscription
              end
              get ":id/gitlab_subscription" do
                present @namespace.gitlab_subscription || {}, with: ::API::Entities::GitlabSubscription
              end
            end
          end
        end
      end
    end
  end
end
