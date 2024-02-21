# frozen_string_literal: true

# EE:Self Managed
module Admin
  class CodeSuggestionsController < Admin::ApplicationController
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    respond_to :html

    feature_category :seat_cost_management
    urgency :low

    before_action :ensure_feature_available!

    def index
      @subscription_name = License.current.subscription_name
    end

    private

    def ensure_feature_available!
      render_404 unless !gitlab_com_subscription? && License.current&.paid? && gitlab_duo_available?
    end
  end
end
