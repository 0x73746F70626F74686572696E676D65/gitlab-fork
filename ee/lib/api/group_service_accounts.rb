# frozen_string_literal: true

module API
  class GroupServiceAccounts < ::API::Base
    include PaginationParams

    feature_category :user_management

    before do
      authenticate!
      authorize! :admin_service_accounts, user_group
    end

    helpers do
      def user
        user_group.provisioned_users.find_by_id(params[:user_id])
      end

      def validate_service_account_user
        not_found!('User') unless user
        bad_request!("User is not of type Service Account") unless user.service_account?
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end

    resource 'groups/:id', requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      resource :service_accounts do
        desc 'Create a service account user' do
          detail 'Create a service account user'
          success Entities::UserSafe
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Group not found' }
          ]
        end

        params do
          optional :name, type: String, desc: 'Name of the user'
          optional :username, type: String, desc: 'Username of the user'
        end

        post do
          organization_id = user_group.organization_id
          service_params = declared_params.merge({ organization_id: organization_id, namespace_id: params[:id] })

          response = ::Namespaces::ServiceAccounts::CreateService
                       .new(current_user, service_params)
                       .execute

          if response.status == :success
            present response.payload, with: Entities::UserSafe, current_user: current_user
          else
            bad_request!(response.message)
          end
        end

        desc 'Get list of service account users' do
          detail 'Get list of service account users'
          success Entities::UserSafe
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Group not found' }
          ]
        end

        params do
          use :pagination
          optional :order_by, type: String, values: %w[id username], default: 'id',
            desc: 'Attribute to sort by'
          optional :sort, type: String, values: %w[asc desc], default: 'desc', desc: 'Order of sorting'
        end

        # rubocop: disable CodeReuse/ActiveRecord -- for the user or reorder
        get do
          users = user_group.service_accounts

          users = users.reorder(params[:order_by] => params[:sort])

          present paginate_with_strategies(users), with: Entities::UserSafe
        end
        # rubocop: enable CodeReuse/ActiveRecord

        desc 'Delete a service account user. Available only for group owners and admins.' do
          failure [
            { code: 400, message: '400 Bad request' },
            { code: 401, message: '401 Unauthorized' },
            { code: 403, message: '403 Forbidden' },
            { code: 404, message: '404 Group not found' }
          ]
        end

        params do
          requires :user_id, type: Integer, desc: 'The ID of the service account user'
          optional :hard_delete, type: Boolean, desc: "Whether to remove a user's contributions"
        end

        delete ":user_id" do
          validate_service_account_user

          delete_params = declared_params(include_missing: false)

          unless user.can_be_removed? || delete_params[:hard_delete]
            conflict!('User cannot be removed while is the sole-owner of a group')
          end

          destroy_conditionally!(user) do
            ::Namespaces::ServiceAccounts::DeleteService
            .new(current_user, user)
            .execute(delete_params)
          end
        end

        resource ":user_id/personal_access_tokens" do
          desc 'Create a personal access token. Available only for group owners.' do
            detail 'This feature was introduced in GitLab 16.1'
            success Entities::PersonalAccessTokenWithToken
          end

          params do
            requires :name, type: String, desc: 'The name of the personal access token'
            requires :scopes, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: ::Gitlab::Auth.all_available_scopes.map(&:to_s),
              desc: 'The array of scopes of the personal access token'
            optional :expires_at, type: Date,
              desc: 'The expiration date of the personal access token in ISO 8601 format'
          end

          post do
            validate_service_account_user

            response = ::PersonalAccessTokens::CreateService.new(
              current_user: current_user, target_user: user, params: declared_params.merge(group: user_group)
            ).execute

            if response.success?
              present response.payload[:personal_access_token], with: Entities::PersonalAccessTokenWithToken
            else
              render_api_error!(response.message, response.http_status || :unprocessable_entity)
            end
          end

          desc 'Rotate personal access token' do
            detail 'Rotates a personal access token.'
            success Entities::PersonalAccessTokenWithToken
          end

          post ':token_id/rotate' do
            validate_service_account_user

            token = PersonalAccessToken.find_by_id(params[:token_id])

            if token&.user == user
              response = ::PersonalAccessTokens::RotateService.new(current_user, token).execute

              if response.success?
                status :ok

                new_token = response.payload[:personal_access_token]
                present new_token, with: Entities::PersonalAccessTokenWithToken
              else
                bad_request!(response.message)
              end
            else
              not_found!
            end
          end
        end
      end
    end
  end
end
