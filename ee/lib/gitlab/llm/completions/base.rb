# frozen_string_literal: true

module Gitlab
  module Llm
    module Completions
      class Base
        def initialize(ai_prompt_class, params = {})
          @ai_prompt_class = ai_prompt_class
          @params = params
        end

        private

        attr_reader :ai_prompt_class, :params

        def response_options
          params.slice(:request_id, :cache_response, :client_subscription_id)
        end

        def tracking_context
          params.slice(:request_id, :action)
        end
      end
    end
  end
end
