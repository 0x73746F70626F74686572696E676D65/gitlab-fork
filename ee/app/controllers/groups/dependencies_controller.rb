# frozen_string_literal: true

module Groups
  class DependenciesController < Groups::ApplicationController
    include GovernUsageGroupTracking

    before_action :authorize_read_dependency_list!
    before_action :validate_project_ids_limit!, only: :index

    feature_category :dependency_management
    urgency :low
    track_govern_activity 'dependencies', :index

    # More details on https://gitlab.com/gitlab-org/gitlab/-/issues/411257#note_1508315283
    GROUP_COUNT_LIMIT = 600
    PROJECT_IDS_LIMIT = 10

    def index
      respond_to do |format|
        format.html do
          set_below_group_limit

          render status: :ok
        end
        format.json do
          dependencies = dependencies_finder.execute.with_component.with_version.with_source.with_project_route
          render json: dependencies_serializer.represent(dependencies)
        end
      end
    end

    def locations
      render json: ::Sbom::DependencyLocationListEntity.represent(
        Sbom::DependencyLocationsFinder.new(
          namespace: group,
          params: params.permit(:component_id, :search)
        ).execute
      )
    end

    def licenses
      return render_not_authorized unless below_group_limit?

      catalogue = Gitlab::SPDX::Catalogue.latest

      licenses = catalogue
        .licenses
        .append(Gitlab::SPDX::License.unknown)
        .sort_by(&:name)

      render json: ::Sbom::DependencyLicenseListEntity.represent(licenses)
    end

    private

    def authorize_read_dependency_list!
      return if can?(current_user, :read_dependency, group)

      render_not_authorized
    end

    def validate_project_ids_limit!
      return unless params.fetch(:project_ids, []).size > PROJECT_IDS_LIMIT

      render_error(
        :unprocessable_entity,
        format(_('A maximum of %{limit} projects can be searched for at one time.'), limit: PROJECT_IDS_LIMIT)
      )
    end

    def dependencies_finder
      ::Sbom::DependenciesFinder.new(group, params: dependencies_finder_params)
    end

    def dependencies_finder_params
      if below_group_limit?
        params.permit(
          :page,
          :per_page,
          :sort,
          :sort_by,
          component_names: [],
          licenses: [],
          package_managers: [],
          project_ids: []
        )
      else
        params.permit(:page, :per_page, :sort, :sort_by)
      end
    end

    def dependencies_serializer
      DependencyListSerializer
        .new(project: nil, group: group, user: current_user)
        .with_pagination(request, response)
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

    def render_error(status, message)
      respond_to do |format|
        format.json do
          render json: { message: message }, status: status
        end
      end
    end

    def set_below_group_limit
      @below_group_limit = below_group_limit?
    end

    def below_group_limit?
      group.count_within_namespaces <= GROUP_COUNT_LIMIT
    end
  end
end
