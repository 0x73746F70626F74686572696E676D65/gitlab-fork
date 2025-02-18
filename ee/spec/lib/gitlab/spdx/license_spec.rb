# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::SPDX::License, feature_category: :software_composition_analysis do
  let(:id) { 'MIT' }
  let(:name) { 'MIT License' }

  subject(:license) { described_class.new(id: id, name: name) }

  describe '.unknown' do
    subject(:unknown) { described_class.unknown }

    it 'returns the unknown license' do
      expect(unknown).to have_attributes(id: 'unknown', name: 'Unknown')
    end
  end

  describe '#key?' do
    it 'returns true for exposed attributes' do
      results = described_class::EXPOSED_ATTRIBUTES.map { |attr| license.key?(attr) }
      expect(results).to all(eq(true))
    end

    it 'returns false for unknown attributes' do
      expect(license.key?(:methods)).to eq(false)
    end
  end

  describe '#[]' do
    it 'returns exposed attributes' do
      expect(license[:id]).to eq(id)
      expect(license[:spdx_identifier]).to eq(id)
      expect(license[:name]).to eq(name)
      expect(license[:url]).to eq('https://spdx.org/licenses/MIT.html')
      expect(license[:deprecated]).to eq(false)
    end

    it 'returns nil for unknown attributes' do
      expect(license[:methods]).to be_nil
    end
  end
end
