# frozen_string_literal: true

module ProductAnalytics
  class Visualization
    attr_reader :type, :project, :data, :options, :config

    def self.from_data(data:, project:)
      config = project.repository.blob_data_at(
        project.repository.root_ref_sha,
        visualization_config_path(data)
      )

      return new(config: config) if config

      file = Rails.root.join('ee/lib/gitlab/analytics/product_analytics/visualizations', "#{data}.yaml")
      Gitlab::PathTraversal.check_path_traversal!(data)
      Gitlab::PathTraversal.check_allowed_absolute_path!(
        file.to_s, [Rails.root.join('ee/lib/gitlab/analytics/product_analytics/visualizations').to_s]
      )
      new(config: File.read(file))
    end

    def initialize(config:)
      @config = YAML.safe_load(config)
      @type = @config['type']
      @options = @config['options']
      @data = @config['data']
    end

    def self.visualization_config_path(data)
      "#{ProductAnalytics::Dashboard::DASHBOARD_ROOT_LOCATION}/visualizations/#{data}.yaml"
    end
  end
end
