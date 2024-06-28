# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class Users < ::API::Base
        feature_category :subscription_management
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource :users do
              desc 'Get a single user' do
                success Entities::Internal::User
              end

              params do
                requires :id, type: Integer, desc: 'The ID of the user'
              end

              get ':id' do
                user = User.find_by_id(params[:id])

                not_found!('User') unless user

                present user, with: Entities::Internal::User
              end
            end
          end
        end
      end
    end
  end
end
