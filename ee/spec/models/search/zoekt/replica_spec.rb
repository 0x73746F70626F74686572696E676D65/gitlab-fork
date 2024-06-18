# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Replica, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:replicas) }
    it { is_expected.to have_many(:indices).inverse_of(:replica) }
  end

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      expect(zoekt_replica).to be_valid
      zoekt_replica.namespace_id = zoekt_replica.namespace_id.next
      expect(zoekt_replica).to be_invalid
    end
  end
end
