# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Update
      class Authorizer
        include Messages

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.authorize(context)
          context => { workspace: RemoteDevelopment::Workspace => workspace, current_user: User => current_user }

          if current_user.can?(:update_workspace, workspace)
            Gitlab::Fp::Result.ok(context)
          else
            Gitlab::Fp::Result.err(Unauthorized.new)
          end
        end
      end
    end
  end
end
