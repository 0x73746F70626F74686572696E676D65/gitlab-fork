# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiSelfHostedModel'], feature_category: :mlops do
  it 'has specific fields' do
    expected_fields = %w[id name created_at modified_at model endpoint has_api_token]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
