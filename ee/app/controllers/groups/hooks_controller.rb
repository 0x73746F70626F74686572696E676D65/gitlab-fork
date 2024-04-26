# frozen_string_literal: true

class Groups::HooksController < Groups::ApplicationController
  include ::WebHooks::HookActions

  # Authorize
  before_action :authorize_read_hook!, only: [:index, :show]
  before_action :authorize_admin_hook!, except: [:index, :show]
  before_action :check_group_webhooks_available!
  before_action :hook, only: [:edit, :update, :test, :destroy]
  before_action -> { check_rate_limit!(:group_testing_hook, scope: [@group, current_user]) }, only: :test

  respond_to :html

  layout 'group_settings'

  urgency :low, [:test]

  def test
    if @group.first_non_empty_project
      service = TestHooks::ProjectService.new(hook, current_user, params[:trigger] || 'push_events')
      service.project = @group.first_non_empty_project
      result = service.execute

      set_hook_execution_notice(result)
    else
      flash[:alert] = _('Hook execution failed. Ensure the group has a project with commits.')
    end

    redirect_back_or_default(default: { action: 'index' })
  end

  private

  def relation
    @group.hooks
  end

  def hook
    @hook ||= @group.hooks.find(params[:id])
  end

  def trigger_values
    GroupHook.triggers.values
  end

  def check_group_webhooks_available!
    render_404 unless @group.licensed_feature_available?(:group_webhooks) || LicenseHelper.show_promotions?(current_user)
  end

  def authorize_read_hook!
    render_404 unless can?(current_user, :read_web_hook, group)
  end

  def authorize_admin_hook!
    render_404 unless can?(current_user, :admin_web_hook, group)
  end
end
