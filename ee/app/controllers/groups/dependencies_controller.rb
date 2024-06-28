# frozen_string_literal: true

module Groups
  class DependenciesController < Groups::ApplicationController
    include GovernUsageGroupTracking
    include Gitlab::Utils::StrongMemoize

    before_action only: :index do
      push_frontend_feature_flag(:group_level_dependencies_filtering_by_packager, group)
      push_frontend_feature_flag(:group_level_dependencies_filtering_by_component, group)
    end

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

    def dependencies
      if using_new_query?
        ::DependencyManagement::AggregationsFinder.new(group, params: dependencies_finder_params).execute
          .with_component
          .with_version
          .keyset_paginate(cursor: params[:cursor], per_page: per_page)
      else
        ::Sbom::DependenciesFinder.new(group, params: dependencies_finder_params).execute
          .with_component
          .with_version
          .with_source
          .with_project_route
      end
    end

    def dependencies_finder_params
      finder_params = if below_group_limit?
                        params.permit(
                          :cursor,
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
                        params.permit(:cursor, :page, :per_page, :sort, :sort_by)
                      end

      finder_params[:sort_by] = map_sort_by(finder_params[:sort_by]) if using_new_query?

      finder_params
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

    def map_sort_by(sort_by)
      case sort_by
      when 'name'
        :component_name
      when 'packager'
        :package_manager
      when 'license'
        :licenses
      when 'severity'
        :highest_severity
      else
        sort_by&.to_sym
      end
    end

    def per_page
      params[:per_page]&.to_i || DependencyManagement::AggregationsFinder::DEFAULT_PAGE_SIZE
    end

    def set_below_group_limit
      @below_group_limit = below_group_limit?
    end

    def below_group_limit?
      group.count_within_namespaces <= GROUP_COUNT_LIMIT
    end

    def using_new_query?
      ::Feature.enabled?(:rewrite_sbom_occurrences_query, group)
    end
    strong_memoize_attr :using_new_query?
  end
end
