# frozen_string_literal: true

module Projects
  class LearnGitlabController < Projects::ApplicationController
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user! # since it is skipped in inherited controller
    before_action :verify_learn_gitlab_available!

    feature_category :onboarding
    urgency :low

    def show
      @hide_importing_alert = true
    end

    private

    def verify_learn_gitlab_available!
      access_denied! unless ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
    end
  end
end
