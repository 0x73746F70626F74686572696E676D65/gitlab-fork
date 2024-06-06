# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro, feature_category: :subscription_management do
  describe '.eligible_namespace?' do
    context 'when namespace_id is blank' do
      it 'returns true for nil' do
        expect(described_class.eligible_namespace?(nil, [])).to be(true)
      end

      it 'returns true for empty string' do
        expect(described_class.eligible_namespace?('', [])).to be(true)
      end
    end

    context 'when namespace_id is present' do
      let_it_be(:namespace) { create(:group) }
      let(:eligible_namespaces) { Namespace.id_in(namespace.id) }

      it 'returns true for an eligible namespace' do
        expect(described_class.eligible_namespace?(namespace.id.to_s, eligible_namespaces)).to be(true)
      end

      it 'returns false for an in-eligible namespace' do
        expect(described_class.eligible_namespace?(non_existing_record_id.to_s, eligible_namespaces)).to be(false)
      end
    end
  end
end
