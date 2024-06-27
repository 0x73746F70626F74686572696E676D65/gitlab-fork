# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class Creator
        include Messages

        RANDOM_STRING_LENGTH = 6

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.create(context)
          context => {
            current_user: User => user,
            params: Hash => params,
          }
          params => {
            agent: Clusters::Agent => agent
          }
          random_string = SecureRandom.alphanumeric(RANDOM_STRING_LENGTH).downcase
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409774
          #       We can come maybe come up with a better/cooler way to get a unique name, for now this works
          context[:workspace_name] = "workspace-#{agent.id}-#{user.id}-#{random_string}"
          context[:workspace_namespace] = "gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}"
          model_errors = nil

          updated_value = ApplicationRecord.transaction do
            initial_result = Gitlab::Fp::Result.ok(context)

            result =
              initial_result
                .and_then(PersonalAccessTokenCreator.method(:create))
                .and_then(WorkspaceCreator.method(:create))
                .and_then(WorkspaceVariablesCreator.method(:create))

            case result
            in { err: PersonalAccessTokenModelCreateFailed |
              WorkspaceModelCreateFailed |
              WorkspaceVariablesModelCreateFailed => message
            }
              model_errors = message.content[:errors]
              raise ActiveRecord::Rollback
            else
              result.unwrap
            end
          end

          return Gitlab::Fp::Result.err(WorkspaceCreateFailed.new({ errors: model_errors })) if model_errors.present?

          Gitlab::Fp::Result.ok(WorkspaceCreateSuccessful.new(updated_value))
        end
      end
    end
  end
end
