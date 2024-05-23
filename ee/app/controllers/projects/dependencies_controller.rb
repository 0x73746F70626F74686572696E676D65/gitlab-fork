# frozen_string_literal: true

module Projects
  class DependenciesController < Projects::ApplicationController
    include SecurityAndCompliancePermissions
    include GovernUsageProjectTracking

    before_action :authorize_read_dependency_list!

    feature_category :dependency_management
    urgency :low
    track_govern_activity 'dependencies', :index

    before_action do
      push_frontend_feature_flag(:project_level_sbom_occurrences, project)
    end

    def index
      respond_to do |format|
        format.html do
          render status: :ok
        end
        format.json do
          render json: serializer.represent(dependencies, build: report_service.build)
        end
      end
    end

    private

    def not_able_to_collect_dependencies?
      !report_service.able_to_fetch? || user_requested_filters_that_they_cannot_see?
    end

    def user_requested_filters_that_they_cannot_see?
      params[:filter] == 'vulnerable' && !can?(current_user, :read_security_resource, project)
    end

    def collect_dependencies
      return [] if not_able_to_collect_dependencies?

      if project_level_sbom_occurrences_enabled?
        dependencies_finder.execute.with_component.with_version.with_source
      else
        ::Security::DependencyListService.new(pipeline: pipeline, params: dependency_list_params).execute
      end
    end

    def authorize_read_dependency_list!
      render_not_authorized unless can?(current_user, :read_dependency, project)
    end

    def dependencies
      @dependencies ||= collect_dependencies
    end

    def pipeline
      @pipeline ||= report_service.pipeline
    end

    def dependency_list_params
      params.permit(:sort_by, :sort, :filter, :page, :per_page, source_types: []).with_defaults(
        source_types: default_source_type_filters)
    end

    def default_source_type_filters
      ::Sbom::Source::DEFAULT_SOURCES.keys + [nil]
    end

    def report_service
      @report_service ||= ::Security::ReportFetchService.new(project, job_artifacts)
    end

    def serializer
      ::DependencyListSerializer.new(project: project, user: current_user).with_pagination(request, response)
    end

    def dependencies_finder
      ::Sbom::DependenciesFinder.new(project, params: dependency_list_params)
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

    def project_level_sbom_occurrences_enabled?
      Feature.enabled?(:project_level_sbom_occurrences, project)
    end

    def job_artifacts
      report_type = project_level_sbom_occurrences_enabled? ? :sbom : :dependency_list
      ::Ci::JobArtifact.of_report_type(report_type)
    end
  end
end
