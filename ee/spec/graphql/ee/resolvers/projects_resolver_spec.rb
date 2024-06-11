# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ProjectsResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#resolve' do
    subject { resolve(described_class, obj: nil, args: filters, ctx: { current_user: user }).items }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:marked_for_deletion_on) { Date.yesterday }
    let_it_be(:hidden_project) { create(:project, :hidden) }
    let_it_be(:aimed_for_deletion_project) do
      create(:project, marked_for_deletion_at: 2.days.ago, pending_delete: false)
    end

    let_it_be(:project_marked_for_deletion) do
      create(:project, marked_for_deletion_at: marked_for_deletion_on, developers: user)
    end

    let(:filters) { {} }

    before_all do
      project.add_developer(user)
      aimed_for_deletion_project.add_developer(user)
      hidden_project.add_developer(user)
    end

    context 'when aimedForDeletion filter is true' do
      let(:filters) { { aimed_for_deletion: true } }

      it { is_expected.to contain_exactly(aimed_for_deletion_project, project_marked_for_deletion) }
    end

    context 'when aimedForDeletion filter is false' do
      let(:filters) { { aimed_for_deletion: false } }

      it { is_expected.to contain_exactly(project, aimed_for_deletion_project, project_marked_for_deletion) }
    end

    context 'when includeHidden filter is true' do
      let(:filters) { { include_hidden: true } }

      it do
        is_expected.to contain_exactly(project, aimed_for_deletion_project, hidden_project, project_marked_for_deletion)
      end
    end

    context 'when includeHidden filter is false' do
      let(:filters) { { include_hidden: false } }

      it { is_expected.to contain_exactly(project, aimed_for_deletion_project, project_marked_for_deletion) }
    end

    context 'when markedForDeletion is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'and a project has been marked for deletion on the given date' do
        let(:filters) { { marked_for_deletion_on: marked_for_deletion_on } }

        it { is_expected.to contain_exactly(project_marked_for_deletion) }
      end

      context 'and no projects have been marked for deletion on the given date' do
        let(:filters) { { marked_for_deletion_on: (marked_for_deletion_on - 2.days) } }

        it { is_expected.to be_empty }
      end
    end
  end
end
