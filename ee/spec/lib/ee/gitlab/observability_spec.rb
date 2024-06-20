# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Observability, feature_category: :tracing do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe '.tracing_url' do
    subject { described_class.tracing_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/traces") }
  end

  describe '.tracing_analytics_url' do
    subject { described_class.tracing_analytics_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/traces/analytics") }
  end

  describe '.services_url' do
    subject { described_class.services_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/services") }
  end

  describe '.operations_url' do
    subject { described_class.operations_url(project) }

    it {
      is_expected.to eq(
        "#{described_class.observability_url}/v3/query/#{project.id}/services/$SERVICE_NAME$/operations"
      )
    }
  end

  describe '.metrics_url' do
    subject { described_class.metrics_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/metrics/autocomplete") }
  end

  describe '.metrics_search_url' do
    subject { described_class.metrics_search_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/metrics/search") }
  end

  describe '.metrics_search_metadata_url' do
    subject { described_class.metrics_search_metadata_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/metrics/searchmetadata") }
  end

  describe '.logs_search_url' do
    subject { described_class.logs_search_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/logs/search") }
  end

  describe '.logs_search_metadata_url' do
    subject { described_class.logs_search_metadata_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/logs/searchmetadata") }
  end

  describe '.analytics_url' do
    subject { described_class.analytics_url(project) }

    it { is_expected.to eq("#{described_class.observability_url}/v3/query/#{project.id}/analytics") }
  end
end
