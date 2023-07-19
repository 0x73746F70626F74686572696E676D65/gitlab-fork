# frozen_string_literal: true

module ProductAnalytics
  class Dashboard
    attr_reader :title, :description, :schema_version, :panels, :project, :config_project, :slug, :path, :user_defined

    DASHBOARD_ROOT_LOCATION = '.gitlab/analytics/dashboards'

    def self.for_project(project)
      config_project = project.analytics_dashboards_configuration_project || project
      raise ArgumentError, 'Project not provided' unless project.present?

      dashboards = []

      root_trees = config_project.repository.tree(:head, DASHBOARD_ROOT_LOCATION)

      dashboards << builtin_dashboards(project) if product_analytics_available?(project)

      dashboards << local_dashboards(config_project, root_trees.trees) if root_trees&.trees

      dashboards.flatten
    end

    def initialize(title:, description:, schema_version:, panels:, project:, slug:, user_defined:, config_project:)
      @title = title
      @description = description
      @schema_version = schema_version
      @panels = panels
      @project = project
      @config_project = config_project
      @slug = slug
      @user_defined = user_defined
    end

    def self.local_dashboards(project, trees)
      config_project = project.analytics_dashboards_configuration_project || project

      trees.delete_if { |tree| tree.name == 'visualizations' }.map do |tree|
        config = YAML.safe_load(
          project.repository.blob_data_at(project.repository.root_ref_sha, "#{tree.path}/#{tree.name}.yaml")
        )

        new(
          project: project,
          title: config['title'],
          slug: tree.name,
          description: config['description'],
          schema_version: config['version'],
          panels: ProductAnalytics::Panel.from_data(config['panels'], project),
          user_defined: true,
          config_project: config_project
        )
      end
    end

    def self.builtin_dashboards(project)
      config_project = project.analytics_dashboards_configuration_project || project

      dashboard_names = %w[audience behavior]
      dashboard_names.map do |name|
        config = YAML.safe_load(
          File.read(Rails.root.join('ee/lib/gitlab/analytics/product_analytics/dashboards', "#{name}.yaml"))
        )

        new(
          project: project,
          title: config['title'],
          slug: name,
          description: config['description'],
          schema_version: config['version'],
          panels: ProductAnalytics::Panel.from_data(config['panels'], project),
          user_defined: false,
          config_project: config_project
        )
      end
    end

    def self.product_analytics_available?(project)
      ::Feature.enabled?(:product_analytics_snowplow_support, project) &&
        project.product_analytics_enabled? &&
        project.project_setting.product_analytics_instrumentation_key
    end

    def ==(other)
      slug == other.slug
    end
  end
end
