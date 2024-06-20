# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAcceptedSelfHostedModels'], feature_category: :custom_models do
  it { expect(described_class.graphql_name).to eq('AiAcceptedSelfHostedModels') }

  it 'exposes all the curated LLMs for self-hosted feature' do
    expect(described_class.values.keys).to include(*%w[MISTRAL MIXTRAL CODEGEMMA])
  end
end
