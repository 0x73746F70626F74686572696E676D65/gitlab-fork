# frozen_string_literal: true

module Organizations
  class GroupsController < ApplicationController
    include ::Groups::Params

    feature_category :cell
    urgency :low, [:create, :new]

    before_action :authorize_create_group!, only: [:new]
    before_action :authorize_read_organization!, only: [:edit]
    before_action :authorize_view_edit_page!, only: [:edit]

    def new; end

    def edit; end

    def create
      response = create_group
      @group = response[:group]

      if response.success?
        render json: GroupSerializer.new(current_user: current_user).represent(@group)
      else
        render json: { message: @group.errors }, status: :unprocessable_entity
      end
    end

    private

    def group
      @group ||= Group.in_organization(organization).find_by_full_path(params[:id])
    end

    def create_group
      create_service_params = group_params.merge(organization_id: organization.id)
      Groups::CreateService.new(current_user, create_service_params).execute
    end

    def authorize_view_edit_page!
      return render_404 if group.nil?

      access_denied! unless can?(current_user, :view_edit_page, group)
    end
  end
end

Organizations::GroupsController.prepend_mod
