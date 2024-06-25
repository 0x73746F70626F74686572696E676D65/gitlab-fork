# frozen_string_literal: true

module EE
  module Projects
    module Settings
      module RepositoryController
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          skip_before_action :authorize_admin_project!, only: [:show, :create_deploy_token]
          before_action :authorize_view_repository_settings!, only: [:show, :create_deploy_token]
          before_action :push_rule, only: :show
        end

        private

        def push_rule
          return unless project.feature_available?(:push_rules)

          unless project.push_rule
            push_rule = project.create_push_rule
            project.project_setting.update(push_rule_id: push_rule.id)
          end

          @push_rule = project.push_rule # rubocop:disable Gitlab/ModuleWithInstanceVariables
        end

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        override :load_gon_index
        def load_gon_index
          super
          gon.push(
            selected_merge_access_levels: @protected_branch.merge_access_levels.map { |access_level| access_level.user_id || access_level.access_level },
            selected_push_access_levels: @protected_branch.push_access_levels.map { |access_level| access_level.user_id || access_level.access_level },
            selected_create_access_levels: @protected_tag.create_access_levels.map { |access_level| access_level.user_id || access_level.access_level }
          )
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        def render_show
          push_rule
          default_branch_blocked_by_security_policy

          super
        end

        override :fetch_protected_branches
        def fetch_protected_branches(project)
          return super unless group_protected_branches_feature_available?(project.group)

          project.all_protected_branches.sorted_by_namespace_and_name.page(pagination_params[:page])
        end

        def fetch_branches_protected_from_push(project)
          return [] unless project.licensed_feature_available?(:security_orchestration_policies)

          ::Security::SecurityOrchestrationPolicies::ProtectedBranchesUnprotectService
            .new(project: project)
            .execute
        end

        # rubocop: disable Gitlab/ModuleWithInstanceVariables
        override :define_protected_refs
        def define_protected_refs
          super
          @branches_protected_from_push = fetch_branches_protected_from_push(@project)

          protected_branches_protected_from_deletion =
            ::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService
              .new(project: project)
              .execute(@protected_branches)

          @protected_branches.each do |protected_branch|
            protected_branch.protected_from_deletion = protected_branch.in?(protected_branches_protected_from_deletion)
          end
        end

        def default_branch_blocked_by_security_policy
          @default_branch_blocked_by_security_policy = ::Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService
            .new(project: @project)
            .execute
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        def group_protected_branches_feature_available?(group)
          allow_protected_branches_for_group?(group) && ::License.feature_available?(:group_protected_branches)
        end

        def allow_protected_branches_for_group?(group)
          ::Feature.enabled?(:group_protected_branches, group) ||
            ::Feature.enabled?(:allow_protected_branches_for_group, group)
        end

        def authorize_view_repository_settings!
          return if can?(current_user, :admin_push_rules, project) ||
            can?(current_user, :manage_deploy_tokens, project)

          authorize_admin_project!
        end
      end
    end
  end
end
