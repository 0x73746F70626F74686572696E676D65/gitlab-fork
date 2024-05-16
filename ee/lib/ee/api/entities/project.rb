# frozen_string_literal: true

module EE
  module API
    module Entities
      module Project
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :preload_relation
          def preload_relation(projects_relation, options = {})
            super(projects_relation).with_compliance_framework_settings.with_group_saml_provider.with_invited_groups
          end
        end

        prepended do
          expose :issues_template,
            if: ->(project, options) {
              project.feature_available?(:issuable_default_templates) &&
                Ability.allowed?(options[:current_user], :read_issue, project)
            }

          expose :merge_requests_template,
            if: ->(project, options) {
              project.feature_available?(:issuable_default_templates) &&
                Ability.allowed?(options[:current_user], :read_merge_request, project)
            }

          with_options if: ->(project, options) { Ability.allowed?(options[:current_user], :admin_project, project) } do
            expose :approvals_before_merge, if: ->(project, _) { project.feature_available?(:merge_request_approvers) }
            expose :mirror, if: ->(project, _) { project.feature_available?(:repository_mirrors) }
            expose :mirror_user_id, if: ->(project, _) { project.mirror? }
            expose :mirror_trigger_builds, if: ->(project, _) { project.mirror? }
            expose :only_mirror_protected_branches, if: ->(project, _) { project.mirror? }
            expose :mirror_overwrites_diverged_branches, if: ->(project, _) { project.mirror? }
            expose :external_authorization_classification_label,
              if: ->(_, _) { License.feature_available?(:external_authorization_service_api_management) }
            expose :marked_for_deletion_at, if: ->(project, _) { project.feature_available?(:adjourned_deletion_for_projects_and_groups) }
            expose :marked_for_deletion_on, if: ->(project, _) { project.feature_available?(:adjourned_deletion_for_projects_and_groups) } do |project, _|
              project.marked_for_deletion_at
            end

            # Expose old field names with the new permissions methods to keep API compatible
            # TODO: remove in API v5, replaced by *_access_level
            expose :requirements_enabled do |project, options|
              project.feature_available?(:requirements, options[:current_user])
            end

            expose :security_and_compliance_enabled do |project, options|
              project.feature_available?(:security_and_compliance, options[:current_user])
            end

            expose :requirements_access_level do |project, _|
              project_feature_string_access_level(project, :requirements)
            end

            expose :compliance_frameworks do |project, _|
              [project.compliance_framework_setting&.compliance_management_framework&.name].compact
            end

            expose :merge_pipelines_enabled?, as: :merge_pipelines_enabled, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
            expose :merge_trains_enabled?, as: :merge_trains_enabled, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
            expose :merge_trains_skip_train_allowed?, as: :merge_trains_skip_train_allowed, if: ->(project, _) { project.feature_available?(:merge_pipelines) }
            expose :only_allow_merge_if_all_status_checks_passed, if: ->(project, _) { project.feature_available?(:external_status_checks) }
            expose :allow_pipeline_trigger_approve_deployment, documentation: { type: 'boolean' }, if: ->(project, _) { project.feature_available?(:protected_environments) }
            expose :prevent_merge_without_jira_issue, if: ->(project, _) { project.feature_available?(:jira_issue_association_enforcement) }

            expose :restrict_pipeline_cancellation_role, as: :ci_restrict_pipeline_cancellation_role, if: ->(project, _) { project.ci_cancellation_restriction.feature_available? }
          end
        end
      end
    end
  end
end
