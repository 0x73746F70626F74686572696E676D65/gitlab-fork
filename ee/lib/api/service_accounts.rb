# frozen_string_literal: true

module API
  class ServiceAccounts < ::API::Base
    include PaginationParams

    extend ActiveSupport::Concern

    before { authenticated_as_admin! }

    resource :service_accounts do
      desc 'Create a service account user. Available only for instance admins.' do
        success Entities::UserSafe
      end

      params do
        optional :name, type: String, desc: 'Name of the user'
        optional :username, type: String, desc: 'Username of the user'
      end

      post feature_category: :user_management do
        response = ::Users::ServiceAccounts::CreateService.new(
          current_user, declared_params.merge(organization_id: Current.organization&.id)
        ).execute

        if response.status == :success
          present response.payload, with: ::API::Entities::UserSafe, current_user: current_user
        elsif response.reason == :forbidden
          forbidden!(response.message)
        else
          bad_request!(response.message)
        end
      end

      desc 'Get list of service account users. Available only for instance admins' do
        detail 'Get list of service account users'
        success Entities::UserSafe
        failure [
          { code: 400, message: '400 Bad request' },
          { code: 401, message: '401 Unauthorized' },
          { code: 403, message: '403 Forbidden' }
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
        authorize! :admin_service_accounts

        users = User.service_account

        users = users.reorder(params[:order_by] => params[:sort])

        present paginate_with_strategies(users), with: Entities::UserSafe
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
