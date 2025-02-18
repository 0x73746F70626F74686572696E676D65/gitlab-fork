# frozen_string_literal: true

module Gitlab
  module Llm
    module Utils
      class Authorizer
        Response = Struct.new(:allowed, :message, keyword_init: true) do
          def allowed?
            allowed
          end
        end

        def self.container(container:, user:)
          if user.can?(:access_duo_features, container)
            Response.new(allowed: true)
          else
            Response.new(allowed: false, message: container_not_allowed_message(container, user))
          end
        end

        def self.resource(resource:, user:)
          return Response.new(allowed: false, message: not_found_message(user)) unless resource && user
          return user_as_resource(resource: resource, user: user) if resource.is_a?(User)

          allowed = user.can?("read_#{resource.to_ability_name}", resource)

          return Response.new(allowed: false, message: not_found_message(user)) unless allowed

          authorization_container = container(container: resource.resource_parent, user: user)

          return authorization_container unless authorization_container.allowed?

          Response.new(allowed: true)
        end

        # Child classes may impose additional restrictions
        def self.user(user:) # rubocop:disable Lint/UnusedMethodArgument -- Argument used by child classes
          Response.new(allowed: true)
        end

        private_class_method def self.user_as_resource(resource:, user:)
          return Response.new(allowed: false, message: not_found_message(user)) if user != resource

          user(user: user)
        end

        private_class_method def self.container_not_allowed_message(container, user)
          container.member?(user) ? no_ai_message(user) : not_found_message(user)
        end

        private_class_method def self.not_found_message(user)
          logger.info_or_debug(user, message: "Resource not found", error_code: "M3003")
          s_("AI|I'm sorry, I can't generate a response. You might want to try again. " \
            "You could also be getting this error because the items you're asking about " \
            "either don't exist, you don't have access to them, or your session has expired.")
        end

        private_class_method def self.no_access_message(user)
          logger.info_or_debug(user, message: "No access to Duo Chat", error_code: "M3004")
          s_("AI|I'm sorry, I can't generate a response. You do not have access to GitLab Duo Chat.")
        end

        private_class_method def self.no_ai_message(user)
          logger.info_or_debug(user, message: "AI is disabled", error_code: "M3002")
          s_("AI|I am sorry, I cannot access the information you are asking about. " \
            "A group or project owner has turned off Duo features in this group or project.")
        end

        private_class_method def self.logger
          Gitlab::Llm::Logger.build
        end
      end
    end
  end
end
