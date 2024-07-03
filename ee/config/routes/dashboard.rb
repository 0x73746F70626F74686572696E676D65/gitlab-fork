# frozen_string_literal: true

resource :dashboard, controller: 'dashboard', only: [] do
  scope module: :dashboard do
    resources :projects, only: [:index] do
      collection do
        ## TODO: Migrate this over to to: 'projects#index' as part of `:your_work_projects_vue` FF rollout
        ## https://gitlab.com/gitlab-org/gitlab/-/issues/465889
        get :removed
      end
    end
  end
end
