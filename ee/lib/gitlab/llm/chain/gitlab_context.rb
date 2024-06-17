# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      class GitlabContext
        attr_accessor :current_user, :container, :resource, :ai_request, :tools_used, :extra_resource, :request_id,
          :current_file, :agent_version

        def initialize(
          current_user:, container:, resource:, ai_request:, extra_resource: {}, request_id: nil,
          current_file: {}, agent_version: nil
        )
          @current_user = current_user
          @container = container
          @resource = resource
          @ai_request = ai_request
          @tools_used = []
          @extra_resource = extra_resource
          @request_id = request_id
          @current_file = (current_file || {}).with_indifferent_access
          @agent_version = agent_version
        end

        def current_page_sentence
          authorized_resource&.current_page_sentence
        end

        def current_page_short_description
          authorized_resource&.current_page_short_description
        end

        def resource_serialized(content_limit:)
          return '' unless authorized_resource

          authorized_resource.serialize_for_ai(
            user: current_user,
            content_limit: content_limit
          ).to_xml(root: :root, skip_types: true, skip_instruct: true)
        end

        private

        # @return [Ai::AiResource::BaseAiResource]
        def authorized_resource
          resource_wrapper_class = "Ai::AiResource::#{resource.class}".safe_constantize
          # We need to implement it for all models we want to take into considerations
          raise ArgumentError, "#{resource.class} is not a valid AiResource class" unless resource_wrapper_class

          return unless Utils::ChatAuthorizer.resource(resource: resource, user: current_user).allowed?

          resource_wrapper_class.new(resource)
        end
      end
    end
  end
end
