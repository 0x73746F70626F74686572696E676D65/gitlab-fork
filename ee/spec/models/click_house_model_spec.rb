# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouseModel, feature_category: :value_stream_management do
  let(:model_class) do
    Class.new(described_class) do
      self.table_name = 'test_table'

      def to_clickhouse_csv_row
        { foo: 'bar' }
      end
    end
  end

  describe '#to_clickhouse_csv_row' do
    it 'raises NoMethodError' do
      expect do
        described_class.new.to_clickhouse_csv_row
      end.to raise_error(NoMethodError)
    end
  end

  describe '#store' do
    subject(:model) { model_class.new }

    it 'saves serialized record to clickhouse buffer' do
      expect(::ClickHouse::WriteBuffer).to receive(:add).with('test_table', { foo: 'bar' })

      model.store
    end
  end

  describe '.related_event?' do
    it 'returns false if no EVENTS defined' do
      expect(model_class.related_event?('foo')).to be_falsey
    end

    context 'with EVENTS const defined' do
      let(:model_class) do
        super().tap do |klass|
          klass::EVENTS = { 'foo' => 1 }.freeze # rubocop:disable RSpec/LeakyConstantDeclaration -- its a dynamic class
        end
      end

      it 'is true for events from EVENTS const' do
        expect(model_class.related_event?('foo')).to be_truthy
        expect(model_class.related_event?('bar')).to be_falsey
      end
    end
  end
end
