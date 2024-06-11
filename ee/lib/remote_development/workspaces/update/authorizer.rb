# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Update
      class Authorizer
        include Messages

        # @param [Hash] context
        # @return [Result]
        def self.authorize(context)
          context => { workspace: RemoteDevelopment::Workspace => workspace, current_user: User => current_user }

          if current_user.can?(:update_workspace, workspace)
            Result.ok(context)
          else
            Result.err(Unauthorized.new)
          end
        end
      end
    end
  end
end
