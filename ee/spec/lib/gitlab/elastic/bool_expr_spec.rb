# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Elastic::BoolExpr, feature_category: :global_search do
  subject(:bool_expr) { described_class.new }

  it 'sets defaults', :aggregate_failures do
    expect(bool_expr[:must]).to eq([])
    expect(bool_expr[:must_not]).to eq([])
    expect(bool_expr[:should]).to eq([])
    expect(bool_expr[:filter]).to eq([])
    expect(bool_expr[:minimum_should_match]).to be_nil
  end

  describe '#reset!', :aggregate_failures do
    it 'resets to defaults' do
      bool_expr[:must] = [1]
      bool_expr[:must_not] = [2]
      bool_expr[:should] = [3]
      bool_expr[:filter] = [4]
      bool_expr[:minimum_should_match] = 5

      bool_expr.reset!

      expect(bool_expr[:must]).to eq([])
      expect(bool_expr[:must_not]).to eq([])
      expect(bool_expr[:should]).to eq([])
      expect(bool_expr[:filter]).to eq([])
      expect(bool_expr[:minimum_should_match]).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash with empty values removed' do
      bool_expr[:must] = [1]
      bool_expr[:should] = [3]
      bool_expr[:minimum_should_match] = 5

      expected_hash = {
        must: [1],
        should: [3],
        minimum_should_match: 5
      }

      expect(bool_expr.to_h).to eq(expected_hash)
    end
  end

  describe '#to_json' do
    it 'returns a json string with empty values removed' do
      bool_expr[:must] = [2]
      bool_expr[:should] = [4]
      bool_expr[:minimum_should_match] = 6

      expected_json = {
        must: [2],
        should: [4],
        minimum_should_match: 6
      }.to_json

      expect(bool_expr.to_json).to eq(expected_json)
    end
  end

  describe '#eql?' do
    let(:another_bool_expr) { described_class.new }

    subject(:eql) { bool_expr.eql?(another_bool_expr) }

    context 'when the other bool_expr has the same values' do
      it 'returns true' do
        bool_expr[:must] = [1]
        bool_expr[:filter] = [0]

        another_bool_expr[:must] = [1]
        another_bool_expr[:filter] = [0]

        expect(eql).to eq(true)
      end
    end

    context 'when the other bool_expr does not have the same values' do
      it 'returns false' do
        bool_expr[:must] = [10]
        bool_expr[:filter] = [0]

        another_bool_expr[:must] = [1]
        another_bool_expr[:filter] = [0]

        expect(eql).to eq(false)
      end
    end
  end
end
