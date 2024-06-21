# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::AiFeaturesCatalogue, feature_category: :ai_abstraction_layer do
  describe 'definitions' do
    it 'has a valid :feature_category set', :aggregate_failures do
      feature_categories = Gitlab::FeatureCategories.default.categories.map(&:to_sym).to_set

      described_class::LIST.each do |action, completion|
        expect(completion[:feature_category]).to be_a(Symbol)
        expect(feature_categories)
          .to(include(completion[:feature_category]), "expected #{action} to declare a valid feature_category")
      end
    end

    it 'has all fields set', :aggregate_failures do
      described_class::LIST.each_value do |completion|
        expect(completion).to include(:service_class,
          :prompt_class,
          :maturity,
          :self_managed,
          :internal,
          :execute_method)
      end
    end
  end

  describe '#external' do
    it 'returns external actions' do
      expect(described_class.external.values.pluck(:internal))
        .not_to include(true)
    end
  end

  describe '#with_service_class' do
    it 'returns external actions' do
      expect(described_class.with_service_class.values.pluck(:service_class))
        .not_to include(nil)
    end
  end

  describe '#for_saas' do
    it 'returns Saas-only actions' do
      expect(described_class.for_saas.values.pluck(:self_managed))
        .not_to include(true)
    end
  end

  describe '#for_sm' do
    it 'returns sm actions' do
      expect(described_class.for_sm.values.pluck(:self_managed))
        .not_to include(false)
    end
  end
end
