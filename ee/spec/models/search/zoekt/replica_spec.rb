# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Replica, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }

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

    describe 'project_can_not_assigned_to_same_replica_unless_index_is_reallocating' do
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:zoekt_index) do
        create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace)
      end

      let_it_be(:zoekt_repository) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index) }

      context 'when a project is assigned to the two indices in the same replica' do
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace)
        end

        let_it_be(:zoekt_repository2) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index2) }

        context 'when one index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :reallocating)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
          end
        end

        context 'when no index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :ready)
          end

          it 'is invalid' do
            expect { zoekt_replica.validate! }.to raise_error(ActiveRecord::RecordInvalid,
              /A project can not be assigned to the same replica unless the index is being reallocated/)
          end
        end
      end

      context 'when a project is assigned to the two indices in the different replica' do
        let_it_be(:zoekt_replica2) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
        let_it_be(:zoekt_index2) do
          create(:zoekt_index, replica: zoekt_replica2, zoekt_enabled_namespace: zoekt_enabled_namespace)
        end

        context 'when one index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :reallocating)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
            expect(zoekt_replica2).to be_valid
          end
        end

        context 'when no index is in reallocating state' do
          before do
            zoekt_index2.update!(state: :ready)
          end

          it 'is valid' do
            expect(zoekt_replica).to be_valid
            expect(zoekt_replica2).to be_valid
          end
        end
      end
    end
  end
end
