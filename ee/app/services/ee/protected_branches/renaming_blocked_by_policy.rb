# frozen_string_literal: true

module EE
  module ProtectedBranches
    module RenamingBlockedByPolicy
      def execute(protected_branch, skip_authorization: false)
        raise ::Gitlab::Access::AccessDeniedError if renaming?(protected_branch) && blocked?(protected_branch)

        super
      end

      private

      def renaming?(protected_branch)
        return false unless params[:name]

        protected_branch.name != params[:name]
      end

      def blocked?(protected_branch)
        return blocking_branch_modification?(protected_branch.project) if protected_branch.project_level?

        blocking_group_branch_modification?(protected_branch.group)
      end

      def blocking_branch_modification?(project)
        return false unless project&.licensed_feature_available?(:security_orchestration_policies)

        project.scan_result_policy_reads.blocking_branch_modification.exists?
      end

      def blocking_group_branch_modification?(group)
        return false unless group&.licensed_feature_available?(:security_orchestration_policies)
        return false unless ::Feature.enabled?(:scan_result_policy_block_group_branch_modification, group)

        ::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService
          .new(group: group)
          .execute
      end
    end
  end
end
