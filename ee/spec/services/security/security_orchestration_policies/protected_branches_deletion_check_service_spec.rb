# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService, "#execute", feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: protected_branch.project) }
  let(:result) { described_class.new(project: project).execute([protected_branch]) }

  before_all do
    project.repository.add_branch(project.creator, protected_branch.name, "HEAD")
  end

  context "without blocking scan result policy" do
    it "excludes the protected branch" do
      expect(result).to exclude(protected_branch)
    end
  end

  context "with blocking scan result policy" do
    include_context 'with scan result policy blocking protected branches' do
      let(:branch_name) { protected_branch.name }

      it_behaves_like 'when policy is applicable based on the policy scope configuration' do
        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end

        context 'when protected branch is not backed by git ref' do
          before do
            project.repository.delete_branch(branch_name)
          end

          after do
            project.repository.add_branch(project.creator, branch_name, "HEAD")
          end

          it "includes the protected branch" do
            expect(result).to include(protected_branch)
          end
        end
      end

      it_behaves_like 'when no policy is applicable due to the policy scope' do
        it "excludes the protected branch" do
          expect(result).to exclude(protected_branch)
        end
      end
    end

    context 'when policy branch specification has wildcard' do
      let_it_be(:protected_branch) { create(:protected_branch, project: project, name: "rc-1") }

      include_context 'with scan result policy blocking protected branches' do
        let(:branch_name) { "rc-*" }

        it "includes the protected branch" do
          expect(result).to include(protected_branch)
        end
      end
    end

    context "with mismatching branch specification" do
      include_context 'with scan result policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }
        let(:scan_result_policy) do
          build(:scan_result_policy, branches: [branch_name.reverse],
            approval_settings: { block_branch_modification: true })
        end

        it "excludes the protected branch" do
          expect(result).to exclude(protected_branch)
        end
      end
    end
  end
end
