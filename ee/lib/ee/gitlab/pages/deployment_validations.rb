# frozen_string_literal: true

module EE
  module Gitlab
    module Pages
      module DeploymentValidations
        extend ::Gitlab::Utils::Override
        extend ActiveSupport::Concern
        include ::Gitlab::Utils::StrongMemoize

        prepended do
          with_options unless: -> { errors.any? } do
            validate :validate_versioned_deployments_limit
            validate :validate_multiple_deployments_enabled
          end
        end

        override :max_size_from_settings
        def max_size_from_settings
          return super unless License.feature_available?(:pages_size_limit)

          project.closest_setting(:max_pages_size).megabytes
        end

        def validate_versioned_deployments_limit
          return if path_prefix.blank?
          return if versioned_deployments_limit > versioned_deployments_count

          errors.add(:base, format(
            _("Namespace reached its allowed limit of %{limit} extra deployments"),
            limit: versioned_deployments_limit
          ))
        end

        def versioned_deployments_limit
          project.actual_limits.active_versioned_pages_deployments_limit_by_namespace.to_i
        end
        strong_memoize_attr :versioned_deployments_limit

        def versioned_deployments_count
          ::PagesDeployment.count_versioned_deployments_for(project, versioned_deployments_limit + 1)
        end
        strong_memoize_attr :versioned_deployments_count

        def validate_multiple_deployments_enabled
          return if path_prefix.blank?
          return if ::Gitlab::Pages.multiple_versions_enabled_for?(project)

          errors.add(:base, _(
            "Configuring path_prefix is only allowed when using multiple pages deployments per project, " \
            "which is disabled for your project."
          ))
        end
      end
    end
  end
end
