# frozen_string_literal: true

module Mutations
  module ContainerRegistry
    module Protection
      module Rule
        class Update < ::Mutations::BaseMutation
          graphql_name 'UpdateContainerRegistryProtectionRule'
          description 'Updates a container registry protection rule to restrict access to project containers. ' \
                      'You can prevent users without certain roles from altering containers. ' \
                      'Available only when feature flag `container_registry_protected_containers` is enabled.'

          authorize :admin_container_image

          argument :id,
            ::Types::GlobalIDType[::ContainerRegistry::Protection::Rule],
            required: true,
            description: 'Global ID of the container registry protection rule to be updated.'

          argument :repository_path_pattern,
            GraphQL::Types::String,
            required: false,
            validates: { allow_blank: false },
            alpha: { milestone: '16.7' },
            description: copy_field_description(
              Types::ContainerRegistry::Protection::RuleType,
              :repository_path_pattern
            )

          argument :minimum_access_level_for_delete,
            Types::ContainerRegistry::Protection::RuleAccessLevelEnum,
            required: false,
            alpha: { milestone: '16.7' },
            description: copy_field_description(
              Types::ContainerRegistry::Protection::RuleType,
              :minimum_access_level_for_delete
            )

          argument :minimum_access_level_for_push,
            Types::ContainerRegistry::Protection::RuleAccessLevelEnum,
            required: false,
            alpha: { milestone: '16.7' },
            description: copy_field_description(
              Types::ContainerRegistry::Protection::RuleType,
              :minimum_access_level_for_push
            )

          field :container_registry_protection_rule,
            Types::ContainerRegistry::Protection::RuleType,
            null: true,
            alpha: { milestone: '16.7' },
            description: 'Container registry protection rule after mutation.'

          def resolve(id:, **kwargs)
            container_registry_protection_rule = authorized_find!(id: id)

            if Feature.disabled?(:container_registry_protected_containers, container_registry_protection_rule.project)
              raise_resource_not_available_error!("'container_registry_protected_containers' feature flag is disabled")
            end

            response = ::ContainerRegistry::Protection::UpdateRuleService.new(container_registry_protection_rule,
              current_user: current_user, params: kwargs).execute

            { container_registry_protection_rule: response.payload[:container_registry_protection_rule],
              errors: response.errors }
          end
        end
      end
    end
  end
end
