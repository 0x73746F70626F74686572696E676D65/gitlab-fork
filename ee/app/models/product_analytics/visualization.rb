# frozen_string_literal: true

module ProductAnalytics
  class Visualization
    include SchemaValidator

    attr_reader :type, :container, :data, :options, :config, :slug, :errors

    VISUALIZATIONS_ROOT_LOCATION = '.gitlab/analytics/dashboards/visualizations'
    SCHEMA_PATH = 'ee/app/validators/json_schemas/analytics_visualization.json'

    PRODUCT_ANALYTICS_PATH = 'ee/lib/gitlab/analytics/product_analytics/visualizations'
    PRODUCT_ANALYTICS_VISUALIZATIONS = %w[
      average_session_duration
      average_sessions_per_user
      browsers_per_users
      daily_active_users
      events_over_time
      page_views_over_time
      returning_users_percentage
      sessions_over_time
      sessions_per_browser
      top_pages
      total_events
      total_pageviews
      total_sessions
      total_unique_users
    ].freeze

    VALUE_STREAM_DASHBOARD_PATH = 'ee/lib/gitlab/analytics/value_stream_dashboard/visualizations'
    VALUE_STREAM_DASHBOARD_VISUALIZATIONS = %w[
      dora_chart
      usage_overview
      dora_performers_score
      deployment_frequency_over_time
      lead_time_for_changes_over_time
      time_to_restore_service_over_time
      change_failure_rate_over_time
    ].freeze

    AI_IMPACT_DASHBOARD_PATH = 'ee/lib/gitlab/analytics/ai_impact_dashboard/visualizations'
    AI_IMPACT_DASHBOARD_VISUALIZATIONS = %w[ai_impact_table].freeze

    def self.for(container:, user:)
      config_project =
        container.analytics_dashboards_configuration_project ||
        container.default_dashboards_configuration_source

      visualizations = []
      visualizations << custom_visualizations(config_project)
      visualizations << builtin_visualizations(container, user)

      visualizations.flatten
    end

    def self.custom_visualizations(config_project)
      trees = config_project&.repository&.tree(:head, VISUALIZATIONS_ROOT_LOCATION)

      return [] unless trees.present?

      trees.entries.map do |entry|
        config = config_project.repository.blob_data_at(config_project.repository.root_ref_sha, entry.path)

        new(config: config, slug: File.basename(entry.name, File.extname(entry.name)))
      end
    end

    def self.get_path_for_visualization(data)
      if VALUE_STREAM_DASHBOARD_VISUALIZATIONS.include?(data)
        VALUE_STREAM_DASHBOARD_PATH
      elsif AI_IMPACT_DASHBOARD_VISUALIZATIONS.include?(data)
        AI_IMPACT_DASHBOARD_PATH
      else
        PRODUCT_ANALYTICS_PATH
      end
    end

    def self.load_visualization_data(data)
      path = get_path_for_visualization(data)
      file = Rails.root.join(path, "#{data}.yaml")
      Gitlab::PathTraversal.check_path_traversal!(data)
      Gitlab::PathTraversal.check_allowed_absolute_path!(
        file.to_s, [Rails.root.join(path).to_s]
      )
      init_error = nil
      begin
        config_file = File.read(file)
      rescue Errno::ENOENT
        init_error = "Visualization file #{data}.yaml not found"
      end
      new(config: config_file, slug: data, init_error: init_error)
    end

    def self.from_data(data:, project:)
      return unless data

      config =
        if project && !project.empty_repo?
          project.repository.blob_data_at(
            project.repository.root_ref_sha,
            visualization_config_path(data)
          )
        end

      return new(config: config, slug: data) if config

      load_visualization_data(data)
    end

    def initialize_with_error(init_error, slug)
      @options = {}
      @type = 'unknown'
      @data = {}
      @errors = [init_error]
      @slug = slug&.parameterize
    end

    def initialize(config:, slug:, init_error: nil)
      if init_error
        initialize_with_error(init_error, slug)
        return
      end

      begin
        @config = YAML.safe_load(config)
        @type = @config['type']
        @options = @config['options']
        @data = @config['data']
      rescue Psych::Exception => e
        @errors = [e.message]
      end
      @slug = slug&.parameterize
      @errors = schema_errors_for(@config)
    end

    def self.visualization_config_path(data)
      "#{ProductAnalytics::Dashboard::DASHBOARD_ROOT_LOCATION}/visualizations/#{data}.yaml"
    end

    def self.load_visualizations(visualization_names, directory)
      visualization_names.map do |name|
        config = File.read(Rails.root.join(directory, "#{name}.yaml"))

        new(config: config, slug: name)
      end
    end

    def self.product_analytics_visualizations
      load_visualizations(PRODUCT_ANALYTICS_VISUALIZATIONS, PRODUCT_ANALYTICS_PATH)
    end

    def self.value_stream_dashboard_visualizations
      load_visualizations(VALUE_STREAM_DASHBOARD_VISUALIZATIONS, VALUE_STREAM_DASHBOARD_PATH)
    end

    def self.builtin_visualizations(container, user)
      visualizations = []

      if container.product_analytics_enabled? && container.product_analytics_onboarded?(user)
        visualizations << product_analytics_visualizations
      end

      visualizations.flatten
    end
  end
end
