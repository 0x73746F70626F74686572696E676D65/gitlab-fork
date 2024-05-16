# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ModelConfigurations::TextEmbeddings, feature_category: :ai_abstraction_layer do
  let_it_be(:host) { 'cloud.gitlab.com' }
  let_it_be(:project) { 'PROJECT' }
  let_it_be(:user) { create(:user) }

  subject(:text) { described_class.new(user: user) }

  before do
    stub_application_setting(vertex_ai_host: host)
    stub_application_setting(vertex_ai_project: project)
  end

  describe '#payload' do
    it 'returns default payload' do
      expect(subject.payload('some content')).to eq(
        {
          instances: [
            {
              content: 'some content'
            }
          ]
        }
      )
    end
  end

  describe '#url' do
    it 'returns correct url replacing default value' do
      expect(subject.url).to eq(
        'https://cloud.gitlab.com/ai/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/textembedding-gecko@003:predict'
      )
    end
  end

  describe '#as_json' do
    it 'returns serializable attributes' do
      attrs = {
        vertex_ai_host: host,
        vertex_ai_project: project,
        model: described_class::NAME
      }

      expect(subject.as_json).to eq(attrs)
    end
  end
end
