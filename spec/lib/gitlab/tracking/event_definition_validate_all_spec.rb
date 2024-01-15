# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::EventDefinition, feature_category: :product_analytics_data_management do
  it 'only has valid event definitions', :aggregate_failures do
    described_class.definitions.each do |definition|
      validation_errors = definition.validation_errors
      expect(validation_errors).to be_empty, validation_errors.join
    end
  end
end
