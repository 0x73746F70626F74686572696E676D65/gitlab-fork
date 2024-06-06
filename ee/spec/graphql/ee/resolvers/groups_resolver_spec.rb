# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GroupsResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:groups_resolver) { resolve(described_class, args: filters, ctx: { current_user: user }) }

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, owners: user) }
    let_it_be(:marked_for_deletion_on) { Date.parse('2024-01-01') }
    let_it_be(:marked_for_deletion_group) do
      create(:group_with_deletion_schedule, marked_for_deletion_on: marked_for_deletion_on, owners: user)
    end

    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    end

    context 'when marked_for_deletion_on is present' do
      context 'and a group has been marked for deletion on the given date' do
        let(:filters) { { marked_for_deletion_on: marked_for_deletion_on.iso8601 } }

        it 'returns groups marked for deletion on the specified date' do
          expect(groups_resolver).to contain_exactly(marked_for_deletion_group)
        end
      end

      context 'and no groups have been marked for deletion on the given date' do
        let(:filters) { { marked_for_deletion_on: (marked_for_deletion_on - 1.day).iso8601 } }

        it 'returns no groups' do
          expect(groups_resolver).to be_empty
        end
      end
    end
  end
end
