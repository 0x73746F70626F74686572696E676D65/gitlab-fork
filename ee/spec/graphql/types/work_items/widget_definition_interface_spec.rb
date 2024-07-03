# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitionInterface, feature_category: :team_planning do
  describe '.resolve_type' do
    subject { described_class.resolve_type(object, {}) }

    context 'for labels widget' do
      let(:object) { build(:widget_definition, widget_type: 'labels') }

      it { is_expected.to eq(Types::WorkItems::WidgetDefinitions::LabelsType) }
    end
  end
end
