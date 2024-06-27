# frozen_string_literal: true

module Subscriptions
  class GroupsController < ApplicationController
    include RoutableActions

    layout 'minimal'

    before_action :authenticate_user!
    before_action :ensure_flow_enabled!, only: :new

    before_action :find_group, except: %i[new create]
    before_action :authorize_admin_group!, except: %i[new create]

    feature_category :subscription_management
    urgency :low

    def new
      @plan_data = find_plan

      return not_found unless @plan_data

      @eligible_groups = fetch_eligible_groups(plan_id: @plan_data[:id])
    end

    def create
      response = Groups::CreateService.new(
        current_user, name: group_params[:name], path: group_params[:path], organization_id: Current.organization_id
      ).execute

      if response.success?
        render json: { id: response[:group].id }, status: :created
      else
        render json: { errors: response[:group]&.errors }, status: :unprocessable_entity
      end
    end

    def edit
      render layout: 'checkout'
    end

    def update
      if Groups::UpdateService.new(@group, current_user, group_params).execute
        notice = if ::Gitlab::Utils.to_boolean(params[:new_user])
                   format(_('Welcome to GitLab, %{first_name}!'), first_name: current_user.first_name)
                 else
                   format(_('Subscription successfully applied to "%{group_name}"'), group_name: @group.name)
                 end

        redirect_to group_path(@group), notice: notice
      else
        @group.path = @group.path_before_last_save || @group.path_was
        render action: :edit, layout: 'checkout'
      end
    end

    private

    def find_group
      @group ||= find_routable!(Group, params[:id], request.fullpath)
    end

    def authorize_admin_group!
      access_denied! unless can?(current_user, :admin_group, @group)
    end

    def ensure_flow_enabled!
      not_found if Feature.disabled?(:migrate_purchase_flows_for_existing_customers, current_user)
    end

    def group_params
      params.require(:group).permit(:name, :path, :visibility_level)
    end

    def build_canonical_path(group)
      url_for(safe_params.merge(id: group.to_param))
    end

    def fetch_eligible_groups(plan_id:)
      return [] unless plan_id

      result = GitlabSubscriptions::FetchPurchaseEligibleNamespacesService.new(
        user: current_user,
        namespaces: current_user.owned_groups.top_most.with_counts(archived: false),
        plan_id: plan_id
      ).execute

      result.success? && result.payload ? result.payload.pluck(:namespace) : [] # rubocop:disable CodeReuse/ActiveRecord -- not an active record model
    end

    def find_plan
      return unless params[:plan_id]

      all_plans = GitlabSubscriptions::FetchSubscriptionPlansService.new(plan: :free).execute

      all_plans.find { |plan| plan[:id] == params[:plan_id] }
    end
  end
end
