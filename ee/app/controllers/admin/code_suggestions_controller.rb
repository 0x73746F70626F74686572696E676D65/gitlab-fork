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
      run_test if CloudConnector::AvailableServices.find_by_name(:code_suggestions)&.purchased?

      @subscription_name = License.current.subscription_name
    end

    private

    def run_test
      error = ::Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(current_user).test_completion

      if error.blank?
        flash.now[:notice] = _('Code completion test was successful')
      else
        flash.now[:alert] = format(_('Code completion test failed: %{error}'), error: error)
      end
    end

    def ensure_feature_available!
      render_404 unless !gitlab_com_subscription? && License.current&.paid? && gitlab_duo_available?
    end
  end
end
