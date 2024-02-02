# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MetricsController, feature_category: :metrics do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let(:path) { nil }
  let(:observability_metrics_ff) { true }
  let(:expected_api_config) do
    {
      oauthUrl: Gitlab::Observability.oauth_url,
      provisioningUrl: Gitlab::Observability.provisioning_url(project),
      tracingUrl: Gitlab::Observability.tracing_url(project),
      tracingAnalyticsUrl: Gitlab::Observability.tracing_analytics_url(project),
      servicesUrl: Gitlab::Observability.services_url(project),
      operationsUrl: Gitlab::Observability.operations_url(project),
      metricsUrl: Gitlab::Observability.metrics_url(project),
      metricsSearchUrl: Gitlab::Observability.metrics_search_url(project),
      metricsSearchMetadataUrl: Gitlab::Observability.metrics_search_metadata_url(project),
      logsSearchUrl: Gitlab::Observability.logs_search_url(project)
    }
  end

  subject(:html_response) do
    get path
    response
  end

  before do
    stub_licensed_features(metrics_observability: true)
    stub_feature_flags(observability_metrics: observability_metrics_ff)
    sign_in(user)
  end

  shared_examples 'metrics route request' do
    it_behaves_like 'observability csp policy' do
      before_all do
        project.add_reporter(user)
      end

      let(:tested_path) { path }
    end

    context 'when user does not have permissions' do
      before_all do
        project.add_guest(user)
      end

      it 'returns 404' do
        expect(html_response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_reporter(user)
      end

      it 'returns 200' do
        expect(html_response).to have_gitlab_http_status(:ok)
      end

      context 'when feature is disabled' do
        let(:observability_metrics_ff) { false }

        it 'returns 404' do
          expect(html_response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET #index' do
    let(:path) { project_metrics_path(project) }

    it_behaves_like 'metrics route request'

    describe 'html response' do
      before_all do
        project.add_reporter(user)
      end

      it 'renders the js-metrics element correctly' do
        element = Nokogiri::HTML.parse(html_response.body).at_css('#js-observability-metrics')

        expected_view_model = {
          apiConfig: expected_api_config
        }.to_json
        expect(element.attributes['data-view-model'].value).to eq(expected_view_model)
      end
    end
  end

  describe 'GET #show' do
    let(:path) { project_metric_path(project, id: 'test.metric', type: 'metric_type') }

    it_behaves_like 'metrics route request'

    describe 'html response' do
      before_all do
        project.add_reporter(user)
      end

      it 'renders the js-metrics-details element correctly' do
        element = Nokogiri::HTML.parse(html_response.body).at_css('#js-observability-metrics-details')

        expected_view_model = {
          apiConfig: expected_api_config,
          metricId: "test.metric",
          metricType: "metric_type",
          metricsIndexUrl: namespace_project_metrics_path(project.group, project)
        }.to_json
        expect(element.attributes['data-view-model'].value).to eq(expected_view_model)
      end
    end
  end
end
