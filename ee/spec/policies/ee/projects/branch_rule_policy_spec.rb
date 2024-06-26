# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchRulePolicy, feature_category: :source_code_management do
  let_it_be(:protected_branch) { create(:protected_branch) }
  let_it_be(:user) { create(:user, maintainer_of: protected_branch.project) }

  let(:branch_rule) { Projects::BranchRule.new(protected_branch.project, protected_branch) }

  subject(:policy) { described_class.new(user, branch_rule) }

  describe 'Abilities' do
    using RSpec::Parameterized::TableSyntax

    where(
      :unprotect_restrictions_enabled, :can_unprotect, :behavior
    ) do
      true                           | true          | 'allows branch rule crud'
      true                           | false         | 'disallows branch rule changes'
      false                          | false         | 'allows branch rule crud'
      false                          | true          | 'allows branch rule crud'
    end

    it_behaves_like 'allows branch rule crud'

    with_them do
      before do
        stub_licensed_features(unprotection_restrictions: unprotect_restrictions_enabled)

        allow(protected_branch)
          .to receive(:can_unprotect?).with(user)
          .and_return(can_unprotect)
      end

      it_behaves_like params[:behavior]
    end
  end
end
