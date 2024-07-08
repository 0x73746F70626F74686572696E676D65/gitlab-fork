# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::AnalyticsPeriodType, feature_category: :fleet_visibility do
  specify { expect(described_class.graphql_name).to eq('PipelineAnalyticsPeriod') }

  it 'exposes the expected fields' do
    expected_fields = %i[
      labels
      totals
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
