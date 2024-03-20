# frozen_string_literal: true

require_relative 'fast_spec_helper'

RSpec.describe RemoteDevelopment::Message, feature_category: :remote_development do
  describe '#==' do
    it 'implements equality' do
      expect(described_class.new({ a: 1 })).to eq(described_class.new(a: 1))
      expect(described_class.new({ a: 1 })).not_to eq(described_class.new(a: 2))
    end
  end

  describe 'validation' do
    it 'requires context to be a Hash' do
      # noinspection RubyMismatchedArgumentType - Intentionally passing wrong type to check runtime type validation
      expect { described_class.new(1) }.to raise_error(ArgumentError, "context must be a Hash")
    end
  end
end
