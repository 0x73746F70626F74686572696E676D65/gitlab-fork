# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Output
        class ResponsePayloadObserver
          # @param [Hash] context
          # @return [Hash]
          def self.observe(context)
            context => {
              agent: agent, # Skip type checking so we can use fast_spec_helper
              update_type: String => update_type,
              response_payload: {
                workspace_rails_infos: Array => workspace_rails_infos,
                settings: {
                  full_reconciliation_interval_seconds: Integer => full_reconciliation_interval_seconds,
                  partial_reconciliation_interval_seconds: Integer => partial_reconciliation_interval_seconds
                },
              },
              observability_for_rails_infos: Hash => observability_for_rails_infos,
              logger: logger, # Skip type checking to avoid coupling to Rails logger
            }

            # NOTE: Do _NOT_ include any values in this logging which:
            #  - Contain potentially sensitive data
            #  - Contain a large amount of raw data which would unnecessarily fill up the logs
            logger.debug(
              message: 'Returning verified response_payload',
              agent_id: agent.id,
              update_type: update_type,
              response_payload: {
                workspace_rails_info_count: workspace_rails_infos.length,
                workspace_rails_infos: workspace_rails_infos.map do |rails_info|
                  rails_info.reject { |k, _| k == :config_to_apply }
                end,
                settings: {
                  full_reconciliation_interval_seconds: full_reconciliation_interval_seconds,
                  partial_reconciliation_interval_seconds: partial_reconciliation_interval_seconds
                }
              },
              observability_for_rails_infos: observability_for_rails_infos
            )

            context
          end
        end
      end
    end
  end
end
