# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Query, feature_category: :global_search do
  describe 'initialize' do
    it 'instance can read the query attribute' do
      expect(described_class.new('test').query).to eq 'test'
    end

    context 'when query is nil' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'query argument can not be nil')
      end
    end

    context 'when query is not passed' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new }.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end
    end
  end

  describe '#exact_search_query' do
    using RSpec::Parameterized::TableSyntax

    where(:query, :result) do
      ''                         | %q("")
      'test'                     | %q("test")
      '"foo"'                    | %q("\"foo\"")
      'lang:ruby    test'        | %q("test" lang:ruby)
      'case:no test'             | %q("test" case:no)
      'foo:bar test'             | %q("foo\:bar\ test")
      'test    case:auto'        | %q("test" case:auto)
      'case:no test f:dummy.rb'  | %q("test" case:no f:dummy.rb)
      'case:no test -f:dummy.rb' | %q("test" case:no -f:dummy.rb)
      'case:no file:dummy test'  | %q("test" case:no file:dummy)
      'case:no -file:dummy test' | %q("test" case:no -file:dummy)
      'test case:no file:dummy'  | %q("test" case:no file:dummy)
      'test sym:foo'             | %q("test" sym:foo)
    end

    with_them do
      it 'returns correct exact search query' do
        expect(described_class.new(query).exact_search_query).to eq result
      end
    end
  end
end
