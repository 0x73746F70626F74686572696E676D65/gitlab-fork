# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProductAnalyticsProjectSettings'], feature_category: :product_analytics_data_management do
  let(:expected_fields) do
    %i[product_analytics_configurator_connection_string
      product_analytics_data_collector_host cube_api_base_url cube_api_key]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
