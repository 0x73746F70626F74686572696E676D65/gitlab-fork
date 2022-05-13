# frozen_string_literal: true

class Groups::UsageQuotasController < Groups::ApplicationController
  include OneTrustCSP

  before_action :authorize_admin_group!
  before_action :verify_usage_quotas_enabled!
  before_action :push_additional_repo_storage_by_namespace_feature, only: :index
  before_action :push_free_user_cap_feature_flags, only: :index

  layout 'group_settings'

  feature_category :purchase

  def index
    @hide_search_settings = true
    @projects = @group.all_projects.with_shared_runners.page(params[:page])
  end

  def pending_members
    render_404 unless @group.apply_user_cap?
    @hide_search_settings = true
  end

  private

  def verify_usage_quotas_enabled!
    render_404 unless License.feature_available?(:usage_quotas)
    render_404 if @group.has_parent?
  end

  def push_additional_repo_storage_by_namespace_feature
    push_to_gon_attributes(:features, :additional_repo_storage_by_namespace, @group.additional_repo_storage_by_namespace_enabled?)
  end

  def push_free_user_cap_feature_flags
    push_frontend_feature_flag(:free_user_cap, @group)
    push_frontend_feature_flag(:preview_free_user_cap, @group)
  end
end
