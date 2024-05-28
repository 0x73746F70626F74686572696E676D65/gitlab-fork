# frozen_string_literal: true

module RemoteDevelopment
  class WorkspacesFeatureFlagController < ApplicationController
    # Authentication is being skipped temporarily because of high priority of delivery and low impact
    # but will be added in the future
    #   Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/461163
    skip_before_action :authenticate_user!

    feature_category :remote_development
    urgency :low

    ALLOWED_FLAGS = [
      "remote_development_namespace_agent_authorization"
    ].freeze

    def show
      flag = permitted_params[:flag]

      return render json: { enabled: false } unless ALLOWED_FLAGS.include?(flag.to_s)

      namespace_id = permitted_params[:namespace_id]
      namespace = ::Namespace.find_by_id(namespace_id)

      return render json: { enabled: false } unless namespace

      begin
        render json: { enabled: Feature.enabled?(flag.to_sym, namespace.root_ancestor) }
      rescue Feature::InvalidFeatureFlagError
        render json: { enabled: false }
      end
    end

    private

    def permitted_params
      params.permit(:flag, :namespace_id)
    end
  end
end
