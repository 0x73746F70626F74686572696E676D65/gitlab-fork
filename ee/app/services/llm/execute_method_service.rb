# frozen_string_literal: true

module Llm
  class ExecuteMethodService < BaseService
    def initialize(user, resource, method, options = {})
      super(user, resource, options)

      @method = method
    end

    def execute
      full_methods_list = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST
      return error('Unknown method') unless full_methods_list.key?(method)

      result = full_methods_list.dig(method, :execute_method).new(user, resource, options).execute

      track_snowplow_event(result)

      result
    end

    private

    attr_reader :method

    def track_snowplow_event(result)
      Gitlab::Tracking.event(
        self.class.to_s,
        "execute_llm_method",
        label: method.to_s,
        property: result.success? ? "success" : "error",
        user: user,
        namespace: namespace,
        project: project
      )
    end
  end
end
