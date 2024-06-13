# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CustomRoles::Definition, feature_category: :permissions do
  describe '.all' do
    subject(:abilities) { described_class.all }

    let_it_be(:yaml_path) { Rails.root.join("ee/config/custom_abilities/*.yml") }

    let_it_be(:defined_abilities) do
      Dir.glob(yaml_path).map do |file|
        File.basename(file, '.yml').to_sym
      end
    end

    context 'when initialized' do
      it 'does not reload the abilities from the yaml files' do
        expect(described_class).not_to receive(:load_abilities!)

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(defined_abilities)
      end
    end

    context 'when not initialized' do
      before do
        described_class.instance_variable_set(:@definitions, nil)
      end

      it 'reloads the abilities from the yaml files' do
        expect(described_class).to receive(:load_abilities!)

        abilities
      end

      it 'returns the defined abilities' do
        expect(abilities.keys).to match_array(defined_abilities)
      end
    end
  end
end
