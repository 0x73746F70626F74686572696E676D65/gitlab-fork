# frozen_string_literal: true

namespace :admin do
  resources :users, only: [], constraints: { id: %r{[a-zA-Z./0-9_\-]+} } do
    member do
      post :identity_verification_exemption
      delete :destroy_identity_verification_exemption
      post :reset_runners_minutes
      get :card_match
      get :phone_match
    end
  end

  scope(
    path: 'groups/*id',
    controller: :groups,
    constraints: { id: Gitlab::PathRegex.full_namespace_route_regex, format: /(html|json|atom)/ }
  ) do
    scope(as: :group) do
      post :reset_runners_minutes
    end
  end

  resource :push_rule, only: [:show, :update]
  resource :email, only: [:show, :create]
  resources :audit_logs, controller: 'audit_logs', only: [:index]
  resources :audit_log_reports, only: [:index], constraints: { format: :csv }
  resources :credentials, only: [:index, :destroy] do
    resources :resources, only: [] do
      put :revoke, controller: :credentials
    end
    member do
      put :revoke
    end
  end
  resources :user_permission_exports, controller: 'user_permission_exports', only: [:index]

  resource :license, only: [:show, :create, :destroy] do
    get :download, on: :member
    post :sync_seat_link, on: :collection

    resource :usage_export, controller: 'licenses/usage_exports', only: [:show]
  end

  resource :subscription, only: [:show]
  resources :role_promotion_requests, only: :index

  get 'code_suggestions', to: 'code_suggestions#index'

  namespace :ai do
    resources :self_hosted_models, only: [:index, :new, :create, :edit, :update, :destroy] do
      collection do
        resources :terms_and_conditions, only: [:index, :create]
      end
    end
    resources :feature_settings, only: [:index, :edit, :update, :create]
  end

  # using `only: []` to keep duplicate routes from being created
  resource :application_settings, only: [] do
    get :seat_link_payload
    match :templates, :advanced_search, :security_and_compliance, :namespace_storage, :analytics, via: [:get, :patch]
    get :geo, to: "geo/settings#show"
    put :update_microsoft_application

    resource :scim_oauth, only: [:create], controller: :scim_oauth, module: 'application_settings'

    resources :roles_and_permissions, only: [:index, :new, :edit], module: 'application_settings'
  end

  namespace :geo do
    get '/' => 'nodes#index'

    resources :nodes, path: 'sites', only: [:index, :create, :new, :edit, :update] do
      member do
        scope '/replication' do
          get '/', to: 'nodes#index'
          get '/:replicable_name_plural', to: 'replicables#index', as: 'site_replicables'
        end
      end
    end

    scope '/replication' do
      get '/', to: redirect(path: 'admin/geo/sites')
      get '/:replicable_name_plural', to: 'replicables#index', as: 'replicables'
    end

    resource :settings, only: [:show, :update]
  end

  namespace :elasticsearch do
    post :enqueue_index
    post :trigger_reindexing
    post :cancel_index_deletion
    post :retry_migration
  end

  get 'namespace_limits', to: 'namespace_limits#index'
  get 'namespace_limits/export_usage', to: 'namespace_limits#export_usage'

  resources :runners, only: [] do
    collection do
      get :dashboard
    end
  end
end
