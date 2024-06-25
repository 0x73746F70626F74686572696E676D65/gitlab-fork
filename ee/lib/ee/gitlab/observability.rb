# frozen_string_literal: true

module EE
  module Gitlab
    module Observability
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      class_methods do
        def analytics_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/analytics"
        end

        def tracing_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/traces"
        end

        def tracing_analytics_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/traces/analytics"
        end

        def services_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/services"
        end

        def operations_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/services/$SERVICE_NAME$/operations"
        end

        def metrics_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/metrics/autocomplete"
        end

        def metrics_search_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/metrics/search"
        end

        def metrics_search_metadata_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/metrics/searchmetadata"
        end

        def logs_search_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/logs/search"
        end

        def logs_search_metadata_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/logs/searchmetadata"
        end
      end
    end
  end
end
