# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class Authorizer
        include Messages

        # @param [Hash] context
        # @return [Result]
        def self.authorize(context)
          context => { current_user: User => current_user, params: Hash => params }
          params => { project: Project => project }

          if current_user.can?(:create_workspace, project)
            Result.ok(context)
          else
            Result.err(Unauthorized.new)
          end
        end
      end
    end
  end
end
