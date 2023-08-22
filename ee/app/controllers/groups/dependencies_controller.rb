# frozen_string_literal: true

module Groups
  class DependenciesController < Groups::ApplicationController
    include GovernUsageGroupTracking

    before_action :authorize_read_dependency_list!

    feature_category :dependency_management
    urgency :low
    track_govern_activity 'dependencies', :index

    # More details on https://gitlab.com/gitlab-org/gitlab/-/issues/411257#note_1508315283
    GROUP_COUNT_LIMIT = 600

    def index
      respond_to do |format|
        format.html do
          set_enable_project_search

          render status: :ok
        end
        format.json do
          render json: serialized_dependencies
        end
      end
    end

    def locations
      render json: locations_info
    end

    private

    def authorize_read_dependency_list!
      return if can?(current_user, :read_dependency, group) && Feature.enabled?(:group_level_dependencies, group)

      render_not_authorized
    end

    def dependency_list_params
      params.permit(:sort_by, :sort, :component_id, :search, package_managers: [])
    end

    def collect_dependencies
      @collect_dependencies ||= ::Sbom::DependenciesFinder.new(group, params: dependency_list_params).execute
    end

    def serialized_dependencies
      DependencyListSerializer.new(
        project: nil,
        user: current_user).with_pagination(request, response).represent(collect_dependencies)
    end

    def render_not_authorized
      respond_to do |format|
        format.html do
          render_404
        end
        format.json do
          render_403
        end
      end
    end

    def locations_info
      ::Sbom::DependencyLocationListEntity.represent(dependency_locations)
    end

    def dependency_locations
      Sbom::DependencyLocationsFinder
        .new(namespace: group, params: dependency_list_params.slice(:component_id, :search))
        .execute
    end

    def set_enable_project_search
      @enable_project_search = group.count_within_namespaces <= GROUP_COUNT_LIMIT
    end
  end
end
