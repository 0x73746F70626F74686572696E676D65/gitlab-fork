# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Projects::ObservabilityHelper, type: :helper, feature_category: :tracing do
  include Gitlab::Routing.url_helpers

  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }

  let(:expected_api_config) do
    {
      oauthUrl: Gitlab::Observability.oauth_url,
      provisioningUrl: Gitlab::Observability.provisioning_url(project),
      tracingUrl: Gitlab::Observability.tracing_url(project),
      tracingAnalyticsUrl: Gitlab::Observability.tracing_analytics_url(project),
      servicesUrl: Gitlab::Observability.services_url(project),
      operationsUrl: Gitlab::Observability.operations_url(project),
      metricsUrl: Gitlab::Observability.metrics_url(project),
      metricsSearchUrl: Gitlab::Observability.metrics_search_url(project)
    }
  end

  describe '#observability_tracing_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config
      }.to_json

      expect(helper.observability_tracing_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_tracing_details_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        traceId: "trace-id",
        tracingIndexUrl: namespace_project_tracing_index_path(project.group, project)
      }.to_json

      expect(helper.observability_tracing_details_model(project, "trace-id")).to eq(expected_json)
    end
  end

  describe '#observability_metrics_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config
      }.to_json

      expect(helper.observability_metrics_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_metrics_details_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        apiConfig: expected_api_config,
        metricId: "test.metric",
        metricType: "metric_type",
        metricsIndexUrl: namespace_project_metrics_path(project.group, project)
      }.to_json

      expect(helper.observability_metrics_details_view_model(project, "test.metric", "metric_type"))
        .to eq(expected_json)
    end
  end
end
