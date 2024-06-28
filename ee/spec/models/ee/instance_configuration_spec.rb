# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InstanceConfiguration, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- controller that is using that model is also not owned
  describe '#settings' do
    describe '#ai_gateway_url' do
      it 'returns ai gateway url' do
        expect(described_class.new.settings).to include(:ai_gateway_url)
      end
    end
  end
end
