# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Sorts, feature_category: :global_search do
  let(:query_hash) { {} }

  describe '#sort_by' do
    using RSpec::Parameterized::TableSyntax

    subject(:sort_by) { described_class.sort_by(query_hash: query_hash, options: options) }

    where(:doc_type, :order_by, :sort, :expected) do
      'issue' | nil | nil | { sort: {} }
      'issue' | 'created_at' | 'asc' | { sort: { created_at: { order: 'asc' } } }
      'issue' | 'created_at' | 'desc' | { sort: { created_at: { order: 'desc' } } }
      'issue' | 'updated_at' | 'asc' | { sort: { updated_at: { order: 'asc' } } }
      'issue' | 'updated_at' | 'desc' | { sort: { updated_at: { order: 'desc' } } }
      'issue' | 'popularity' | 'asc' | { sort: { upvotes: { order: 'asc' } } }
      'issue' | 'popularity' | 'desc' | { sort: { upvotes: { order: 'desc' } } }
      'foo' | 'popularity' | 'asc' | { sort: {} }
      'foo' | 'popularity' | 'desc' | { sort: {} }
      'issue' | nil | 'created_asc' | { sort: { created_at: { order: 'asc' } } }
      'issue' | nil | 'created_desc' | { sort: { created_at: { order: 'desc' } } }
      'issue' | nil | 'updated_asc' | { sort: { updated_at: { order: 'asc' } } }
      'issue' | nil | 'updated_desc' | { sort: { updated_at: { order: 'desc' } } }
      'issue' | nil | 'popularity_asc' | { sort: { upvotes: { order: 'asc' } } }
      'issue' | nil | 'popularity_desc' | { sort: { upvotes: { order: 'desc' } } }
      'foo' | nil | 'popularity_asc' | { sort: {} }
      'foo' | nil | 'popularity_desc' | { sort: {} }
    end

    with_them do
      let(:options) { { doc_type: doc_type, order_by: order_by, sort: sort } }

      it { is_expected.to eq(expected) }
    end
  end
end
