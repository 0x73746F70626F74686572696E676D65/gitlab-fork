# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Input
        class ParamsValidator
          include Messages
          include UpdateTypes

          # @param [Hash] context
          # @return [Gitlab::Fp::Result]
          def self.validate(context)
            context => { original_params: Hash => original_params }

            # NOTE: We deep_stringify_keys here, because even though they will be strings in the a real request,
            #       so we can still pass keys as symbols during tests, and not have to worry about passing string
            #       keys in tests. This is the only place where keys need to be strings, because of the JSON schema
            #       validation, all other places we convert and work with the keys as symbols.
            errors = validate_original_params_against_schema(original_params.deep_stringify_keys)

            if errors.none?
              Gitlab::Fp::Result.ok(context)
            else
              Gitlab::Fp::Result.err(WorkspaceReconcileParamsValidationFailed.new(details: errors.join(". ")))
            end
          end

          # @param [Hash] original_params
          # @return [Array]
          def self.validate_original_params_against_schema(original_params)
            workspace_error_details_schema = {
              "required" => %w[error_type],
              "properties" => {
                "error_type" => {
                  "type" => "string",
                  "enum" => [ErrorType::APPLIER, ErrorType::KUBERNETES]
                },
                "error_message" => {
                  "type" => "string"
                }
              }
            }
            workspace_agent_info_schema = {
              "properties" => {
                "termination_progress" => {
                  "type" => "string",
                  "enum" => [TerminationProgress::TERMINATING, TerminationProgress::TERMINATED]
                },
                "error_details" => workspace_error_details_schema
              }
            }

            schema = {
              "type" => "object",
              "required" => %w[update_type workspace_agent_infos],
              "properties" => {
                "update_type" => {
                  "type" => "string",
                  "enum" => [PARTIAL, FULL]
                },
                "workspace_agent_infos" => {
                  "type" => "array",
                  "items" => workspace_agent_info_schema
                }
              }
            }

            schemer = JSONSchemer.schema(schema)
            errors = schemer.validate(original_params)
            errors.map { |error| JSONSchemer::Errors.pretty(error) }
          end
          private_class_method :validate_original_params_against_schema
        end
      end
    end
  end
end
