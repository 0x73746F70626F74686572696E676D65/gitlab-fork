# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ProjectsResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#resolve' do
    subject { resolve(described_class, obj: nil, args: filters, ctx: { current_user: user }).items }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:hidden_project) { create(:project, :hidden) }
    let_it_be(:aimed_for_deletion_project) do
      create(:project, marked_for_deletion_at: 2.days.ago, pending_delete: false)
    end

    let(:filters) { {} }

    before_all do
      project.add_developer(user)
      aimed_for_deletion_project.add_developer(user)
      hidden_project.add_developer(user)
    end

    context 'when aimedForDeletion filter is true' do
      let(:filters) { { aimed_for_deletion: true } }

      it { is_expected.to contain_exactly(aimed_for_deletion_project) }
    end

    context 'when aimedForDeletion filter is false' do
      let(:filters) { { aimed_for_deletion: false } }

      it { is_expected.to contain_exactly(project, aimed_for_deletion_project) }
    end

    context 'when includeHidden filter is true' do
      let(:filters) { { include_hidden: true } }

      it { is_expected.to contain_exactly(project, aimed_for_deletion_project, hidden_project) }
    end

    context 'when includeHidden filter is false' do
      let(:filters) { { include_hidden: false } }

      it { is_expected.to contain_exactly(project, aimed_for_deletion_project) }
    end
  end
end
